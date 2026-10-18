import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'audio_ringer.dart';
import 'call_ringer.dart';

CallRinger createRinger() => WebRinger();

/// Web: looping ringtone plus a browser notification when the tab is hidden.
class WebRinger extends AudioRinger {
  WebRinger() {
    _requestPermission();
  }

  web.Notification? _notification;

  void _requestPermission() {
    try {
      if (web.Notification.permission == 'default') {
        web.Notification.requestPermission();
      }
    } catch (_) {}
  }

  @override
  Future<void> startIncoming({required String callId, required String callerName}) async {
    await super.startIncoming(callId: callId, callerName: callerName);
    try {
      if (web.document.hidden && web.Notification.permission == 'granted') {
        _notification = web.Notification(
          'Incoming video call',
          web.NotificationOptions(body: '$callerName is calling you', tag: callId),
        );
        _notification!.onclick = ((web.Event _) {
          web.window.focus();
          _notification?.close();
        }).toJS;
      }
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    _notification?.close();
    _notification = null;
    await super.stop();
  }
}
