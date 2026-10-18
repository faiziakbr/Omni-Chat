import 'package:firebase_database/firebase_database.dart';

import '../../../core/rtdb_paths.dart';
import '../../auth/data/app_user.dart';
import '../../contacts/data/contact.dart';
import 'call_models.dart';

/// WebRTC signaling over RTDB:
///   calls/{id}                    call doc (status, offer, answer)
///   calls/{id}/callerCandidates   ICE from caller
///   calls/{id}/calleeCandidates   ICE from callee
///   incomingCall/{calleeUid}      "you're being called" pointer
class SignalingRepository {
  SignalingRepository({required this._me, FirebaseDatabase? database})
    : _db = database ?? FirebaseDatabase.instance;

  final AppUser _me;
  final FirebaseDatabase _db;

  AppUser get me => _me;

  DatabaseReference _call(String id) => _db.ref(RtdbPaths.call(id));

  // ---------------------------------------------------------------- incoming

  Stream<IncomingCall?> incomingCalls() => _db
      .ref(RtdbPaths.incomingCall(_me.uid))
      .onValue
      .map((e) => IncomingCall.tryParse(e.snapshot.value));

  Future<void> clearIncoming() => _db.ref(RtdbPaths.incomingCall(_me.uid)).remove();

  // ---------------------------------------------------------------- call doc

  /// Creates `calls/{id}` in the ringing state and returns its id.
  Future<String> createCall(Contact callee) async {
    final ref = _db.ref('calls').push();
    await ref.set({
      'callerId': _me.uid,
      'calleeId': callee.uid,
      'callerName': _me.name,
      'calleeName': callee.name,
      'status': CallStatus.ringing.name,
      'createdAt': ServerValue.timestamp,
    });
    return ref.key!;
  }

  Future<void> setOffer(String callId, SessionDescription offer) =>
      _call(callId).child('offer').set(offer.toMap());

  Future<void> setAnswer(String callId, SessionDescription answer) =>
      _call(callId).update({'answer': answer.toMap(), 'status': CallStatus.accepted.name});

  Future<void> setStatus(String callId, CallStatus status) =>
      _call(callId).child('status').set(status.name);

  /// Points the callee at the call, which is what makes their app ring.
  Future<void> ring({required String calleeId, required String callId}) =>
      _db.ref(RtdbPaths.incomingCall(calleeId)).set({
        'callId': callId,
        'callerId': _me.uid,
        'callerName': _me.name,
        'createdAt': ServerValue.timestamp,
      });

  /// Caller-side: removes the ring pointer if it's still ours.
  Future<void> cancelRing(String calleeId) => _db.ref(RtdbPaths.incomingCall(calleeId)).remove();

  Future<CallDoc?> getCall(String callId) async {
    final snap = await _call(callId).get();
    return CallDoc.tryParse(callId, snap.value);
  }

  /// Emits null once the doc is deleted (or becomes unreadable).
  Stream<CallDoc?> watchCall(String callId) =>
      _call(callId).onValue.map((e) => CallDoc.tryParse(callId, e.snapshot.value));

  Future<void> deleteCall(String callId) => _call(callId).remove();

  /// If this client drops mid-call, the server marks the call ended.
  Future<void> armDisconnectEnd(String callId) =>
      _call(callId).child('status').onDisconnect().set(CallStatus.ended.name);

  Future<void> disarmDisconnectEnd(String callId) =>
      _call(callId).child('status').onDisconnect().cancel();

  // ---------------------------------------------------------------- ICE

  Future<void> addCandidate(
    String callId, {
    required bool fromCaller,
    required IceCandidateData candidate,
  }) =>
      _call(callId)
          .child(fromCaller ? 'callerCandidates' : 'calleeCandidates')
          .push()
          .set(candidate.toMap());

  Stream<IceCandidateData> remoteCandidates(String callId, {required bool fromCaller}) =>
      _call(callId)
          .child(fromCaller ? 'callerCandidates' : 'calleeCandidates')
          .onChildAdded
          .map((e) => IceCandidateData.tryParse(e.snapshot.value))
          .where((c) => c != null)
          .cast<IceCandidateData>();
}
