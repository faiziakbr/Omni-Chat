import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart' as ck;
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';

import 'audio_ringer.dart';
import 'call_ringer.dart';

CallRinger createRinger() => NativeCallRinger();

/// Android: full-screen incoming-call UI with the system ringtone.
/// iOS: CallKit. Both via flutter_callkit_incoming. Ringback uses [AudioRinger].
///
/// Only rings while the app process is alive (no VoIP push in v1).
class NativeCallRinger extends AudioRinger {
  NativeCallRinger() {
    _eventSub = FlutterCallkitIncoming.onEvent.listen(_onEvent, onError: (_) {});
    _requestPermissions();
  }

  static const _uuid = Uuid();

  late final StreamSubscription<ck.CallEvent?> _eventSub;
  final _actions = StreamController<RingerAction>.broadcast();

  /// System-UI id (UUID, required by CallKit) of the current call.
  String? _activeId;

  /// True once the user answered from the system UI; then it stays up for the
  /// whole call (CallKit owns the audio session) instead of being dismissed.
  bool _answeredInSystemUi = false;

  /// Ids we ended ourselves; their echoed decline/ended events are ignored.
  final Set<String> _selfEnded = {};

  @override
  Stream<RingerAction> get actions => _actions.stream;

  Future<void> _requestPermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await FlutterCallkitIncoming.requestNotificationPermission({
        'title': 'Notification permission',
        'rationaleMessagePermission': 'Needed to show incoming calls.',
        'postNotificationMessageRequired':
            'Allow notifications in Settings so you can see incoming calls.',
      });
      if (!await FlutterCallkitIncoming.canUseFullScreenIntent()) {
        await FlutterCallkitIncoming.requestFullIntentPermission();
      }
    } catch (e) {
      debugPrint('callkit permissions: $e');
    }
  }

  /// CallKit wants a UUID; derive a stable one from the RTDB call id.
  static String _systemId(String callId) => _uuid.v5(Namespace.url.value, 'omnichat:$callId');

  @override
  Future<void> startIncoming({required String callId, required String callerName}) async {
    _activeId = _systemId(callId);
    _answeredInSystemUi = false;
    try {
      await FlutterCallkitIncoming.showCallkitIncoming(
        ck.CallKitParams(
          id: _activeId!,
          nameCaller: callerName,
          appName: 'Omni Chat',
          handle: 'Video call',
          type: 1, // video
          duration: 45000,
          extra: {'callId': callId},
          missedCallNotification: const ck.NotificationParams(
            showNotification: true,
            isShowCallback: false,
            subtitle: 'Missed video call',
          ),
          android: const ck.AndroidParams(
            isCustomNotification: true,
            isShowLogo: false,
            ringtonePath: 'system_ringtone_default',
            backgroundColor: '#1E3A8A',
            actionColor: '#4CAF50',
            textColor: '#FFFFFF',
            incomingCallNotificationChannelName: 'Incoming calls',
            missedCallNotificationChannelName: 'Missed calls',
            isShowFullLockedScreen: true,
            textAccept: 'Accept',
            textDecline: 'Decline',
          ),
          ios: const ck.IOSParams(
            handleType: 'generic',
            supportsVideo: true,
            maximumCallGroups: 1,
            maximumCallsPerCallGroup: 1,
            supportsDTMF: false,
            supportsHolding: false,
            supportsGrouping: false,
            supportsUngrouping: false,
            includesCallsInRecents: true,
            configureAudioSession: true,
            audioSessionMode: 'videoChat',
          ),
        ),
      );
    } catch (e) {
      // Fall back to the in-app ringtone if the system UI is unavailable.
      debugPrint('showCallkitIncoming failed: $e');
      await super.startIncoming(callId: callId, callerName: callerName);
    }
  }

  @override
  Future<void> stop() async {
    await super.stop();
    // Answered/declined in-app while the system UI is still up: dismiss it.
    if (!_answeredInSystemUi) await _endSystemCall();
  }

  @override
  Future<void> connected() async {
    final id = _activeId;
    if (id == null || !_answeredInSystemUi) return;
    try {
      await FlutterCallkitIncoming.setCallConnected(id);
    } catch (_) {}
  }

  @override
  Future<void> ended() async {
    await super.stop();
    await _endSystemCall();
    _answeredInSystemUi = false;
  }

  Future<void> _endSystemCall() async {
    final id = _activeId;
    if (id == null) return;
    _activeId = null;
    _selfEnded.add(id);
    try {
      await FlutterCallkitIncoming.endCall(id);
    } catch (_) {}
  }

  void _onEvent(ck.CallEvent? event) {
    final (String? id, RingerAction? action) = switch (event) {
      ck.CallEventActionCallAccept(:final callKitParams) => (
        callKitParams.id,
        RingerAction.accepted,
      ),
      ck.CallEventActionCallDecline(:final callKitParams) => (
        callKitParams.id,
        RingerAction.declined,
      ),
      ck.CallEventActionCallEnded(:final callKitParams) => (callKitParams.id, RingerAction.ended),
      _ => (null, null),
    };
    if (id == null || action == null) return;
    if (_selfEnded.remove(id)) return; // echo of our own endCall
    if (id != _activeId) return; // stale call
    if (action == RingerAction.accepted) _answeredInSystemUi = true;
    if (action != RingerAction.accepted) _activeId = null;
    _actions.add(action);
  }

  @override
  Future<void> dispose() async {
    await ended();
    await _eventSub.cancel();
    await _actions.close();
    await super.dispose();
  }
}
