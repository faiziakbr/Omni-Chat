import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../core/email_key.dart';
import '../../../core/rtdb_paths.dart';
import 'app_user.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  factory AuthFailure.fromCode(String code) => AuthFailure(switch (code) {
    'invalid-email' => 'That email address is not valid.',
    'email-already-in-use' => 'An account already exists for that email.',
    'weak-password' => 'Password must be at least 6 characters.',
    'user-disabled' => 'This account has been disabled.',
    'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Incorrect email or password.',
    'too-many-requests' => 'Too many attempts. Try again later.',
    'network-request-failed' => 'No internet connection.',
    'operation-not-allowed' => 'Email/password sign-in is not enabled for this Firebase project.',
    _ => 'Something went wrong ($code).',
  });

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository({FirebaseAuth? auth, FirebaseDatabase? database})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = database ?? FirebaseDatabase.instance;

  final FirebaseAuth _auth;
  final FirebaseDatabase _db;

  /// Completes when an in-flight [register] has written the profile.
  Completer<void>? _registration;

  /// Emits the signed-in user, or null when signed out.
  ///
  /// Sign-up signs the user in before the display name is set; that early
  /// emission is held until [register] finishes, otherwise the session would
  /// start (and stamp outgoing messages and calls) with an empty name.
  Stream<AppUser?> get user => _auth.userChanges().asyncMap((u) async {
    final pending = _registration;
    if (u == null || pending == null) return _toAppUser(u);
    await pending.future;
    return _toAppUser(_auth.currentUser);
  });

  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final registration = _registration = Completer<void>();
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      await user.updateDisplayName(name.trim());
      final appUser = AppUser(uid: user.uid, name: name.trim(), email: email.trim().toLowerCase());
      await _db.ref().update({
        RtdbPaths.user(user.uid): {...appUser.toMap(), 'createdAt': ServerValue.timestamp},
        RtdbPaths.emailIndex(emailKey(email)): user.uid,
      });
      await user.reload();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    } finally {
      _registration = null;
      registration.complete();
    }
  }

  Future<void> logIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    }
  }

  final _beforeLogOut = <Future<void> Function()>[];

  /// Runs while the user is still signed in (e.g. presence offline, close local DB).
  void addLogoutHook(Future<void> Function() hook) => _beforeLogOut.add(hook);

  void removeLogoutHook(Future<void> Function() hook) => _beforeLogOut.remove(hook);

  Future<void> logOut() async {
    for (final hook in List.of(_beforeLogOut)) {
      try {
        await hook();
      } catch (_) {
        // Never block logout on cleanup.
      }
    }
    await _auth.signOut();
  }

  AppUser? _toAppUser(User? user) => user == null
      ? null
      : AppUser(uid: user.uid, name: user.displayName ?? '', email: user.email ?? '');
}
