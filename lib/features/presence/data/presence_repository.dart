import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import '../../../core/rtdb_paths.dart';
import 'presence.dart';

class PresenceRepository {
  PresenceRepository({FirebaseDatabase? database}) : _db = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;
  StreamSubscription<DatabaseEvent>? _connectedSub;

  static final _offline = {'online': false, 'lastSeen': ServerValue.timestamp};
  static final _online = {'online': true, 'lastSeen': ServerValue.timestamp};

  /// Marks [uid] online on every (re)connect and registers an onDisconnect
  /// that flips it back to offline if the socket drops or the tab closes.
  void goOnline(String uid) {
    final ref = _db.ref(RtdbPaths.presence(uid));
    _connectedSub?.cancel();
    _connectedSub = _db.ref(RtdbPaths.connected).onValue.listen((event) async {
      if (event.snapshot.value != true) return;
      await ref.onDisconnect().set(_offline);
      await ref.set(_online);
    });
  }

  /// Call while still signed in (before signOut), otherwise the write is rejected.
  Future<void> goOffline(String uid) async {
    await _connectedSub?.cancel();
    _connectedSub = null;
    final ref = _db.ref(RtdbPaths.presence(uid));
    await ref.onDisconnect().cancel();
    await ref.set(_offline);
  }

  Stream<Presence> watch(String uid) => _db
      .ref(RtdbPaths.presence(uid))
      .onValue
      .map((e) => Presence.fromMap(e.snapshot.value as Map<dynamic, dynamic>?));
}
