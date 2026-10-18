import 'package:firebase_database/firebase_database.dart';

import '../../../core/rtdb_paths.dart';

class ConnectivityRepository {
  ConnectivityRepository({FirebaseDatabase? database})
    : _db = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  /// Whether the RTDB socket is up. Emits false until the first connect, and
  /// again on every drop, so callers should debounce before reacting.
  Stream<bool> watchConnected() =>
      _db.ref(RtdbPaths.connected).onValue.map((e) => e.snapshot.value == true);
}
