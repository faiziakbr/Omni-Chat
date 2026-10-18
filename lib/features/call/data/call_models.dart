import 'package:equatable/equatable.dart';

enum CallStatus { ringing, accepted, rejected, busy, missed, cancelled, ended }

/// `calls/{id}`
class CallDoc extends Equatable {
  const CallDoc({
    required this.id,
    required this.callerId,
    required this.calleeId,
    required this.callerName,
    required this.calleeName,
    required this.status,
    this.offer,
    this.answer,
  });

  static CallDoc? tryParse(String id, Object? value) {
    if (value is! Map) return null;
    final callerId = value['callerId'];
    final calleeId = value['calleeId'];
    if (callerId is! String || calleeId is! String) return null;
    return CallDoc(
      id: id,
      callerId: callerId,
      calleeId: calleeId,
      callerName: value['callerName'] as String? ?? '',
      calleeName: value['calleeName'] as String? ?? '',
      status: CallStatus.values.asNameMap()[value['status']] ?? CallStatus.ended,
      offer: SessionDescription.tryParse(value['offer']),
      answer: SessionDescription.tryParse(value['answer']),
    );
  }

  final String id;
  final String callerId;
  final String calleeId;
  final String callerName;
  final String calleeName;
  final CallStatus status;
  final SessionDescription? offer;
  final SessionDescription? answer;

  bool get isTerminal => status != CallStatus.ringing && status != CallStatus.accepted;

  @override
  List<Object?> get props => [
    id,
    callerId,
    calleeId,
    callerName,
    calleeName,
    status,
    offer,
    answer,
  ];
}

/// `incomingCall/{me}`
class IncomingCall extends Equatable {
  const IncomingCall({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.createdAt,
  });

  static IncomingCall? tryParse(Object? value) {
    if (value is! Map) return null;
    final callId = value['callId'];
    final callerId = value['callerId'];
    if (callId is! String || callerId is! String) return null;
    return IncomingCall(
      callId: callId,
      callerId: callerId,
      callerName: value['callerName'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(value['createdAt'] as int? ?? 0),
    );
  }

  final String callId;
  final String callerId;
  final String callerName;
  final DateTime createdAt;

  /// Older than this and the caller has certainly given up.
  static const maxAge = Duration(seconds: 60);

  bool isStale(DateTime now) => now.difference(createdAt) > maxAge;

  @override
  List<Object?> get props => [callId, callerId, callerName, createdAt];
}

/// Plain SDP, independent of flutter_webrtc types.
class SessionDescription extends Equatable {
  const SessionDescription({required this.sdp, required this.type});

  static SessionDescription? tryParse(Object? value) {
    if (value is! Map) return null;
    final sdp = value['sdp'];
    final type = value['type'];
    return sdp is String && type is String ? SessionDescription(sdp: sdp, type: type) : null;
  }

  final String sdp;
  final String type;

  Map<String, String> toMap() => {'sdp': sdp, 'type': type};

  @override
  List<Object?> get props => [sdp, type];
}

class IceCandidateData extends Equatable {
  const IceCandidateData({required this.candidate, this.sdpMid, this.sdpMLineIndex});

  static IceCandidateData? tryParse(Object? value) {
    if (value is! Map) return null;
    final candidate = value['candidate'];
    if (candidate is! String || candidate.isEmpty) return null;
    return IceCandidateData(
      candidate: candidate,
      sdpMid: value['sdpMid'] as String?,
      sdpMLineIndex: value['sdpMLineIndex'] as int?,
    );
  }

  final String candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;

  Map<String, Object?> toMap() => {
    'candidate': candidate,
    'sdpMid': sdpMid,
    'sdpMLineIndex': sdpMLineIndex,
  };

  @override
  List<Object?> get props => [candidate, sdpMid, sdpMLineIndex];
}
