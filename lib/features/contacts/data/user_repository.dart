import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../core/email_key.dart';
import '../../../core/rtdb_paths.dart';
import '../../auth/data/app_user.dart';
import 'contact.dart';

class UserLookupFailure implements Exception {
  const UserLookupFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class UserRepository {
  UserRepository({FirebaseDatabase? database}) : _db = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  /// Exact-match lookup through `emailIndex`. Returns null when nobody has that email.
  Future<AppUser?> findByEmail(String email) async {
    try {
      final uidSnap = await _db.ref(RtdbPaths.emailIndex(emailKey(email))).get();
      final uid = uidSnap.value as String?;
      if (uid == null) return null;
      return await getUser(uid);
    } on FirebaseException catch (e) {
      throw UserLookupFailure(e.message ?? 'Lookup failed');
    }
  }

  Future<AppUser?> getUser(String uid) async {
    final snap = await _db.ref(RtdbPaths.user(uid)).get();
    final value = snap.value;
    return value is Map ? AppUser.fromMap(uid, value) : null;
  }

  /// My contact list, most recently active first.
  Stream<List<Contact>> contacts(String uid) =>
      _db.ref(RtdbPaths.userChats(uid)).onValue.asyncMap((event) async {
        final value = event.snapshot.value;
        if (value is! Map) return const <Contact>[];
        final list = await Future.wait([
          for (final entry in value.entries)
            if (entry.value is Map)
              _withProfile(Contact.fromMap(entry.key as String, entry.value as Map)),
        ]);
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return List<Contact>.unmodifiable(list);
      });

  /// Fills in a contact whose entry was written without a name (e.g. by a
  /// peer who had only just signed up) from their `users/{uid}` profile.
  Future<Contact> _withProfile(Contact contact) async {
    if (contact.name.isNotEmpty) return contact;
    final user = await getUser(contact.uid).catchError((Object _) => null);
    if (user == null || user.name.isEmpty) return contact;
    return Contact(
      uid: contact.uid,
      name: user.name,
      email: contact.email.isEmpty ? user.email : contact.email,
      updatedAt: contact.updatedAt,
    );
  }

  /// Adds each user to the other's contact list (or bumps `updatedAt`).
  Future<void> linkContacts({required AppUser me, required AppUser peer}) {
    final now = ServerValue.timestamp;
    return _db.ref().update({
      '${RtdbPaths.userChats(me.uid)}/${peer.uid}': {
        'peerName': peer.name,
        'peerEmail': peer.email,
        'updatedAt': now,
      },
      '${RtdbPaths.userChats(peer.uid)}/${me.uid}': {
        'peerName': me.name,
        'peerEmail': me.email,
        'updatedAt': now,
      },
    });
  }
}
