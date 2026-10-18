part of 'call_bloc.dart';

sealed class CallEvent extends Equatable {
  const CallEvent();
  @override
  List<Object?> get props => [];
}

/// Start listening for incoming calls (once per session).
final class CallSubscriptionRequested extends CallEvent {
  const CallSubscriptionRequested();
}

final class CallStarted extends CallEvent {
  const CallStarted(this.peer);
  final Contact peer;
  @override
  List<Object?> get props => [peer];
}

final class CallAccepted extends CallEvent {
  const CallAccepted();
}

final class CallDeclined extends CallEvent {
  const CallDeclined();
}

final class CallHungUp extends CallEvent {
  const CallHungUp();
}

final class CallMicToggled extends CallEvent {
  const CallMicToggled();
}

final class CallCameraToggled extends CallEvent {
  const CallCameraToggled();
}

final class CallCameraSwitched extends CallEvent {
  const CallCameraSwitched();
}

final class CallSpeakerToggled extends CallEvent {
  const CallSpeakerToggled();
}

// ---- internal ----

final class _IncomingChanged extends CallEvent {
  const _IncomingChanged(this.incoming);
  final IncomingCall? incoming;
  @override
  List<Object?> get props => [incoming];
}

final class _CallDocChanged extends CallEvent {
  const _CallDocChanged(this.doc);
  final CallDoc? doc;
  @override
  List<Object?> get props => [doc];
}

final class _RemoteCandidateReceived extends CallEvent {
  const _RemoteCandidateReceived(this.candidate);
  final IceCandidateData candidate;
  @override
  List<Object?> get props => [candidate];
}

final class _RemoteStreamReceived extends CallEvent {
  const _RemoteStreamReceived(this.stream);
  final MediaStream stream;
  @override
  List<Object?> get props => [stream];
}

final class _PeerStateChanged extends CallEvent {
  const _PeerStateChanged(this.peerState);
  final PeerState peerState;
  @override
  List<Object?> get props => [peerState];
}

final class _RingTimedOut extends CallEvent {
  const _RingTimedOut();
}

final class _DisconnectTimedOut extends CallEvent {
  const _DisconnectTimedOut();
}

final class _ResetRequested extends CallEvent {
  const _ResetRequested();
}

final class _RingerActionReceived extends CallEvent {
  const _RingerActionReceived(this.action);
  final RingerAction action;
  @override
  List<Object?> get props => [action];
}
