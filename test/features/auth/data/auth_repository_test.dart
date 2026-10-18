import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omni_chat/features/auth/data/app_user.dart';
import 'package:omni_chat/features/auth/data/auth_repository.dart';

class _MockAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockCredential extends Mock implements UserCredential {}

class _MockDatabase extends Mock implements FirebaseDatabase {}

class _MockRef extends Mock implements DatabaseReference {}

void main() {
  late _MockAuth auth;
  late _MockUser user;
  late StreamController<User?> userChanges;
  late AuthRepository repository;
  String? displayName;

  setUp(() {
    auth = _MockAuth();
    user = _MockUser();
    userChanges = StreamController<User?>();
    displayName = null;

    final db = _MockDatabase();
    final ref = _MockRef();
    when(() => db.ref()).thenReturn(ref);
    when(() => ref.update(any())).thenAnswer((_) async {});

    final cred = _MockCredential();
    when(() => cred.user).thenReturn(user);
    when(() => user.uid).thenReturn('alice');
    when(() => user.email).thenReturn('alice@x.com');
    when(() => user.displayName).thenAnswer((_) => displayName);
    when(() => user.reload()).thenAnswer((_) async {});
    when(() => user.updateDisplayName(any())).thenAnswer((inv) async {
      displayName = inv.positionalArguments.first as String?;
      userChanges.add(user);
    });

    when(() => auth.userChanges()).thenAnswer((_) => userChanges.stream);
    when(() => auth.currentUser).thenAnswer((_) => user);
    // Like Firebase: sign-up signs in (and emits) before the name is set.
    when(
      () => auth.createUserWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {
      userChanges.add(user);
      return cred;
    });

    repository = AuthRepository(auth: auth, database: db);
  });
  tearDown(() => unawaited(userChanges.close()));

  test('first signed-in user after sign-up already carries the name', () async {
    final first = repository.user.firstWhere((u) => u != null);
    await repository.register(name: 'Alice', email: 'alice@x.com', password: 'secret1');
    expect(await first, const AppUser(uid: 'alice', name: 'Alice', email: 'alice@x.com'));
  });

  test('a normal sign-in passes straight through', () async {
    displayName = 'Alice';
    final first = repository.user.first;
    userChanges.add(user);
    expect(await first, const AppUser(uid: 'alice', name: 'Alice', email: 'alice@x.com'));
  });
}
