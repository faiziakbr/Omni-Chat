import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStream;

import '../../chat/data/chat_repository.dart';
import '../../contacts/data/contact.dart';
import '../data/call_models.dart';
import '../data/ringer/call_ringer.dart';
import '../data/signaling_repository.dart';
import '../data/webrtc_service.dart';

part 'call_event.dart';
part 'call_state.dart';

/// Session-wide 1v1 call state machine. Every event, internal or from the UI,
/// goes through one sequential handler so transitions never interleave.
class CallBloc extends Bloc<CallEvent, CallState> {
  CallBloc({
    required this._signaling,
    required this._webRtc,
    required this._ringer,
    required this._chatRepository,
    this.ringTimeout = const Duration(seconds: 45),
    this.disconnectGrace = const Duration(seconds: 10),
    this.endedDisplay = const Duration(seconds: 2),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now,
       super(const CallState()) {
    on<CallEvent>(_onEvent, transformer: sequential());

    _subs.addAll([
      _webRtc.localCandidates.listen(_sendLocalCandidate),
      _webRtc.remoteStreams.listen((s) => add(_RemoteStreamReceived(s))),
      _webRtc.peerStates.listen((s) => add(_PeerStateChanged(s))),
      _ringer.actions.listen((a) => add(_RingerActionReceived(a))),
    ]);
  }

  final SignalingRepository _signaling;
  final WebRtcService _webRtc;
  final CallRinger _ringer;
  final ChatRepository _chatRepository;
  final DateTime Function() _now;

  final Duration ringTimeout;
  final Duration disconnectGrace;
  final Duration endedDisplay;

  final List<StreamSubscription<dynamic>> _subs = [];
  StreamSubscription<IncomingCall?>? _incomingSub;

  /// Per-call subscriptions and timers, torn down in [_end].
  final List<StreamSubscription<dynamic>> _callSubs = [];
  Timer? _ringTimer;
  Timer? _disconnectTimer;
  Timer? _resetTimer;

  Future<void> _onEvent(CallEvent event, Emitter<CallState> emit) => switch (event) {
    CallSubscriptionRequested() => _onSubscriptionRequested(),
    CallStarted(:final peer) => _onStarted(peer, emit),
    CallAccepted() => _onAccepted(emit),
    CallDeclined() => _onDeclined(emit),
    CallHungUp() => _onHungUp(emit),
    CallMicToggled() => _onMicToggled(emit),
    CallCameraToggled() => _onCameraToggled(emit),
    CallCameraSwitched() => _webRtc.switchCamera(),
    _IncomingChanged(:final incoming) => _onIncoming(incoming, emit),
    _CallDocChanged(:final doc) => _onDocChanged(doc, emit),
    _RemoteCandidateReceived(:final candidate) => _webRtc.addRemoteCandidate(candidate),
    _RemoteStreamReceived(:final stream) => _onRemoteStream(stream, emit),
    _PeerStateChanged(:final peerState) => _onPeerState(peerState, emit),
    _RingTimedOut() => _onRingTimedOut(emit),
    _DisconnectTimedOut() => _onDisconnectTimedOut(emit),
    _ResetRequested() => _onReset(emit),
    _RingerActionReceived(:final action) => switch (action) {
      RingerAction.accepted => _onAccepted(emit),
      RingerAction.declined => _onDeclined(emit),
      RingerAction.ended => _onHungUp(emit),
    },
  };

  // ------------------------------------------------------------------ setup

  Future<void> _onSubscriptionRequested() async {
    await _incomingSub?.cancel();
    _incomingSub = _signaling.incomingCalls().listen(
      (ic) => add(_IncomingChanged(ic)),
      onError: (_) {},
    );
  }

  // --------------------------------------------------------------- outgoing

  Future<void> _onStarted(Contact peer, Emitter<CallState> emit) async {
    if (state.phase == CallPhase.ended) _clearEnded(emit);
    if (state.phase != CallPhase.idle) return;

    emit(
      CallState(phase: CallPhase.outgoing, peerId: peer.uid, peerName: peer.name, isCaller: true),
    );
    try {
      final local = await _webRtc.openMedia();
      emit(state.copyWith(localStream: local));

      final callId = await _signaling.createCall(peer);
      emit(state.copyWith(callId: callId));

      await _webRtc.createPeer();
      final offer = await _webRtc.createOffer();
      await _signaling.setOffer(callId, offer);
      await _signaling.armDisconnectEnd(callId);

      _watchCall(callId, remoteIsCaller: false);
      await _signaling.ring(calleeId: peer.uid, callId: callId);
      await _ringer.startRingback();
      _ringTimer = Timer(ringTimeout, () => add(const _RingTimedOut()));
    } on MediaAccessFailure catch (e) {
      await _end(emit, CallEndReason.mediaDenied, setRemote: CallStatus.cancelled, error: '$e');
    } catch (e) {
      await _end(emit, CallEndReason.failed, setRemote: CallStatus.cancelled, error: '$e');
    }
  }

  // --------------------------------------------------------------- incoming

  Future<void> _onIncoming(IncomingCall? incoming, Emitter<CallState> emit) async {
    if (incoming == null || incoming.callId == state.callId) return;

    if (incoming.isStale(_now())) {
      await _quietly(_signaling.clearIncoming);
      await _log(incoming.callId, incoming.callerId, 'Missed video call', outgoing: false);
      return;
    }

    if (state.phase == CallPhase.ended) _clearEnded(emit);
    if (state.phase != CallPhase.idle) {
      // Already on a call: tell the new caller we're busy.
      await _quietly(() => _signaling.setStatus(incoming.callId, CallStatus.busy));
      await _quietly(_signaling.clearIncoming);
      await _log(incoming.callId, incoming.callerId, 'Missed video call (busy)', outgoing: false);
      return;
    }

    final doc = await _signaling.getCall(incoming.callId).catchError((Object _) => null);
    if (doc == null || doc.status != CallStatus.ringing) {
      await _quietly(_signaling.clearIncoming);
      return;
    }

    emit(
      CallState(
        phase: CallPhase.incoming,
        callId: doc.id,
        peerId: doc.callerId,
        peerName: doc.callerName,
        isCaller: false,
      ),
    );
    _watchCall(doc.id, remoteIsCaller: true, candidates: false);
    await _ringer.startIncoming(callId: doc.id, callerName: doc.callerName);
    _ringTimer = Timer(ringTimeout, () => add(const _RingTimedOut()));
  }

  Future<void> _onAccepted(Emitter<CallState> emit) async {
    if (state.phase != CallPhase.incoming) return;
    final callId = state.callId!;
    _ringTimer?.cancel();
    await _ringer.stop();
    await _quietly(_signaling.clearIncoming);
    emit(state.copyWith(phase: CallPhase.connecting));

    try {
      final local = await _webRtc.openMedia();
      emit(state.copyWith(localStream: local));
      await _webRtc.createPeer();

      final doc = await _signaling.getCall(callId);
      final offer = doc?.offer;
      if (doc == null || offer == null || doc.isTerminal) {
        await _end(emit, CallEndReason.missed);
        return;
      }
      final answer = await _webRtc.createAnswer(offer);
      await _signaling.setAnswer(callId, answer);
      await _signaling.armDisconnectEnd(callId);
      _callSubs.add(
        _signaling
            .remoteCandidates(callId, fromCaller: true)
            .listen((c) => add(_RemoteCandidateReceived(c)), onError: (_) {}),
      );
    } on MediaAccessFailure catch (e) {
      await _end(emit, CallEndReason.mediaDenied, setRemote: CallStatus.rejected, error: '$e');
    } catch (e) {
      await _end(emit, CallEndReason.failed, setRemote: CallStatus.ended, error: '$e');
    }
  }

  Future<void> _onDeclined(Emitter<CallState> emit) async {
    if (state.phase != CallPhase.incoming) return;
    await _quietly(_signaling.clearIncoming);
    await _end(emit, CallEndReason.declined, setRemote: CallStatus.rejected);
  }

  // ------------------------------------------------------------- in a call

  Future<void> _onHungUp(Emitter<CallState> emit) async {
    switch (state.phase) {
      case CallPhase.outgoing:
        await _quietly(() => _signaling.cancelRing(state.peerId!));
        await _end(emit, CallEndReason.cancelled, setRemote: CallStatus.cancelled);
      case CallPhase.incoming:
        await _onDeclined(emit);
      case CallPhase.connecting:
      case CallPhase.active:
        await _end(emit, CallEndReason.hungUp, setRemote: CallStatus.ended);
      case CallPhase.idle:
      case CallPhase.ended:
        return;
    }
  }

  Future<void> _onDocChanged(CallDoc? doc, Emitter<CallState> emit) async {
    if (!state.inCall) return;
    if (doc == null) {
      await _end(emit, _remoteEndReason(CallStatus.ended));
      return;
    }
    if (doc.isTerminal) {
      await _end(emit, _remoteEndReason(doc.status));
      return;
    }
    // Caller: the callee answered.
    final answer = doc.answer;
    if (state.isCaller && answer != null && !_webRtc.hasRemoteDescription) {
      _ringTimer?.cancel();
      await _ringer.stop();
      emit(state.copyWith(phase: CallPhase.connecting));
      try {
        await _webRtc.acceptAnswer(answer);
      } catch (e) {
        await _end(emit, CallEndReason.failed, setRemote: CallStatus.ended, error: '$e');
      }
    }
  }

  CallEndReason _remoteEndReason(CallStatus status) {
    if (state.isCaller) {
      return switch (status) {
        CallStatus.rejected => CallEndReason.declinedByPeer,
        CallStatus.busy => CallEndReason.busy,
        CallStatus.missed => CallEndReason.noAnswer,
        _ when state.phase == CallPhase.outgoing => CallEndReason.noAnswer,
        _ => CallEndReason.remoteHungUp,
      };
    }
    return state.phase == CallPhase.incoming ? CallEndReason.missed : CallEndReason.remoteHungUp;
  }

  Future<void> _onRemoteStream(MediaStream stream, Emitter<CallState> emit) async {
    if (state.inCall) emit(state.copyWith(remoteStream: stream));
  }

  Future<void> _onPeerState(PeerState peerState, Emitter<CallState> emit) async {
    if (!state.inCall) return;
    switch (peerState) {
      case PeerState.connected:
        _disconnectTimer?.cancel();
        if (state.phase != CallPhase.active) {
          await _ringer.connected();
          emit(
            state.copyWith(
              phase: CallPhase.active,
              connectedAt: state.connectedAt ?? _now(),
              reconnecting: false,
            ),
          );
        } else {
          emit(state.copyWith(reconnecting: false));
        }
      case PeerState.disconnected:
        emit(state.copyWith(reconnecting: true));
        _disconnectTimer?.cancel();
        _disconnectTimer = Timer(disconnectGrace, () => add(const _DisconnectTimedOut()));
      case PeerState.failed:
        await _end(emit, CallEndReason.failed, setRemote: CallStatus.ended);
      case PeerState.connecting:
      case PeerState.closed:
        return;
    }
  }

  Future<void> _onRingTimedOut(Emitter<CallState> emit) async {
    switch (state.phase) {
      case CallPhase.outgoing:
        await _quietly(() => _signaling.cancelRing(state.peerId!));
        await _end(emit, CallEndReason.noAnswer, setRemote: CallStatus.missed);
      case CallPhase.incoming:
        await _quietly(_signaling.clearIncoming);
        await _end(emit, CallEndReason.missed);
      default:
        return;
    }
  }

  Future<void> _onDisconnectTimedOut(Emitter<CallState> emit) async {
    if (state.phase == CallPhase.active || state.phase == CallPhase.connecting) {
      await _end(emit, CallEndReason.failed, setRemote: CallStatus.ended);
    }
  }

  Future<void> _onMicToggled(Emitter<CallState> emit) async {
    if (!state.inCall) return;
    _webRtc.setMicEnabled(!state.micOn);
    emit(state.copyWith(micOn: !state.micOn));
  }

  Future<void> _onCameraToggled(Emitter<CallState> emit) async {
    if (!state.inCall) return;
    _webRtc.setCameraEnabled(!state.cameraOn);
    emit(state.copyWith(cameraOn: !state.cameraOn));
  }

  Future<void> _onReset(Emitter<CallState> emit) async {
    if (state.phase == CallPhase.ended) emit(const CallState());
  }

  void _clearEnded(Emitter<CallState> emit) {
    _resetTimer?.cancel();
    emit(const CallState());
  }

  // ---------------------------------------------------------------- helpers

  void _watchCall(String callId, {required bool remoteIsCaller, bool candidates = true}) {
    _callSubs.add(
      _signaling
          .watchCall(callId)
          .listen(
            (doc) => add(_CallDocChanged(doc)),
            // Permission denied once the doc is deleted → treat as gone.
            onError: (_) => add(const _CallDocChanged(null)),
          ),
    );
    if (candidates) {
      _callSubs.add(
        _signaling
            .remoteCandidates(callId, fromCaller: remoteIsCaller)
            .listen((c) => add(_RemoteCandidateReceived(c)), onError: (_) {}),
      );
    }
  }

  void _sendLocalCandidate(IceCandidateData candidate) {
    final callId = state.callId;
    if (callId == null || !state.inCall) return;
    _signaling
        .addCandidate(callId, fromCaller: state.isCaller, candidate: candidate)
        .catchError((Object _) {});
  }

  /// Single exit path for every way a call can end.
  Future<void> _end(
    Emitter<CallState> emit,
    CallEndReason reason, {
    CallStatus? setRemote,
    String? error,
  }) async {
    final callId = state.callId;
    final peerId = state.peerId;
    final wasCaller = state.isCaller;
    final connectedAt = state.connectedAt;

    _ringTimer?.cancel();
    _disconnectTimer?.cancel();
    for (final s in _callSubs) {
      await s.cancel();
    }
    _callSubs.clear();
    await _ringer.ended();

    if (callId != null) {
      if (setRemote != null) await _quietly(() => _signaling.setStatus(callId, setRemote));
      await _quietly(() => _signaling.disarmDisconnectEnd(callId));
      if (wasCaller) {
        // Give the callee a moment to observe the final status, then clean up.
        Future<void>.delayed(
          const Duration(seconds: 3),
          () => _signaling.deleteCall(callId),
        ).catchError((Object _) {});
      }
    }
    await _webRtc.close();

    if (callId != null && peerId != null) {
      final duration = connectedAt == null ? null : _now().difference(connectedAt);
      await _log(callId, peerId, _logText(reason, wasCaller, duration), outgoing: wasCaller);
    }

    emit(
      CallState(
        phase: CallPhase.ended,
        callId: callId,
        peerId: peerId,
        peerName: state.peerName,
        isCaller: wasCaller,
        connectedAt: connectedAt,
        endReason: reason,
        error: error,
      ),
    );
    _resetTimer?.cancel();
    _resetTimer = Timer(endedDisplay, () => add(const _ResetRequested()));
  }

  static String _logText(CallEndReason reason, bool outgoing, Duration? duration) {
    if (duration != null) {
      return '${outgoing ? 'Outgoing' : 'Incoming'} video call · ${formatCallDuration(duration)}';
    }
    return switch (reason) {
      CallEndReason.noAnswer => 'No answer',
      CallEndReason.declinedByPeer => 'Call declined',
      CallEndReason.busy => 'Busy',
      CallEndReason.cancelled => 'Cancelled call',
      CallEndReason.missed => 'Missed video call',
      CallEndReason.declined => 'Declined call',
      CallEndReason.mediaDenied => 'Call failed (no camera/mic access)',
      CallEndReason.failed => 'Call failed',
      CallEndReason.hungUp || CallEndReason.remoteHungUp => 'Video call',
    };
  }

  Future<void> _log(String callId, String peerId, String text, {required bool outgoing}) =>
      _quietly(
        () => _chatRepository.addCallLog(
          callId: callId,
          peerId: peerId,
          text: text,
          outgoing: outgoing,
        ),
      );

  static Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    _ringTimer?.cancel();
    _disconnectTimer?.cancel();
    _resetTimer?.cancel();
    final callId = state.callId;
    if (state.inCall && callId != null) {
      // Signing out mid-call: tell the other side.
      await _quietly(() => _signaling.setStatus(callId, CallStatus.ended));
    }
    for (final s in [..._subs, ..._callSubs]) {
      await s.cancel();
    }
    await _incomingSub?.cancel();
    await _webRtc.close();
    await _ringer.dispose();
    return super.close();
  }
}

String formatCallDuration(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:${(m % 60).toString().padLeft(2, '0')}:$s' : '$m:$s';
}
