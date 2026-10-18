import 'call_ringer_native.dart' if (dart.library.js_interop) 'call_ringer_web.dart' as impl;

/// What the user did on a system call UI (CallKit / Android full-screen).
enum RingerAction { accepted, declined, ended }

/// Rings for incoming calls and plays ringback for outgoing ones. On mobile it
/// also drives the system call UI, which can outlive the ringing (CallKit).
abstract class CallRinger {
  factory CallRinger() => impl.createRinger();

  Future<void> startIncoming({required String callId, required String callerName});

  Future<void> startRingback();

  /// Stops ringing sounds and dismisses an unanswered system call UI.
  Future<void> stop();

  /// The media connection is up (CallKit shows the call as connected).
  Future<void> connected();

  /// The call is over: tear down any system call UI.
  Future<void> ended();

  /// Accept/decline/end taps from a system call UI. Empty where there is none (web).
  Stream<RingerAction> get actions;

  Future<void> dispose();
}
