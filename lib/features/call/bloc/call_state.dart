part of 'call_bloc.dart';

enum CallPhase { idle, outgoing, incoming, connecting, active, ended }

enum CallEndReason {
  hungUp,
  remoteHungUp,
  declined,
  declinedByPeer,
  busy,
  noAnswer,
  missed,
  cancelled,
  failed,
  mediaDenied,
}

final class CallState extends Equatable {
  const CallState({
    this.phase = CallPhase.idle,
    this.callId,
    this.peerId,
    this.peerName = '',
    this.isCaller = false,
    this.localStream,
    this.remoteStream,
    this.micOn = true,
    this.cameraOn = true,
    this.reconnecting = false,
    this.connectedAt,
    this.endReason,
    this.error,
  });

  final CallPhase phase;
  final String? callId;
  final String? peerId;
  final String peerName;
  final bool isCaller;
  final MediaStream? localStream;
  final MediaStream? remoteStream;
  final bool micOn;
  final bool cameraOn;
  final bool reconnecting;
  final DateTime? connectedAt;
  final CallEndReason? endReason;
  final String? error;

  /// Ringing, connecting or connected.
  bool get inCall => phase != CallPhase.idle && phase != CallPhase.ended;

  CallState copyWith({
    CallPhase? phase,
    String? callId,
    MediaStream? localStream,
    MediaStream? remoteStream,
    bool? micOn,
    bool? cameraOn,
    bool? reconnecting,
    DateTime? connectedAt,
  }) => CallState(
    phase: phase ?? this.phase,
    callId: callId ?? this.callId,
    peerId: peerId,
    peerName: peerName,
    isCaller: isCaller,
    localStream: localStream ?? this.localStream,
    remoteStream: remoteStream ?? this.remoteStream,
    micOn: micOn ?? this.micOn,
    cameraOn: cameraOn ?? this.cameraOn,
    reconnecting: reconnecting ?? this.reconnecting,
    connectedAt: connectedAt ?? this.connectedAt,
    endReason: endReason,
    error: error,
  );

  @override
  List<Object?> get props => [
    phase,
    callId,
    peerId,
    peerName,
    isCaller,
    localStream,
    remoteStream,
    micOn,
    cameraOn,
    reconnecting,
    connectedAt,
    endReason,
    error,
  ];
}
