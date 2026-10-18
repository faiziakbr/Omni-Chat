import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omni_chat/features/auth/bloc/auth_bloc.dart';
import 'package:omni_chat/features/auth/data/app_user.dart';
import 'package:omni_chat/features/auth/data/auth_repository.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  const user = AppUser(uid: 'u1', name: 'Ann', email: 'ann@x.com');
  late _MockAuthRepository repo;

  setUp(() => repo = _MockAuthRepository());

  test('initial state is unknown', () {
    expect(AuthBloc(authRepository: repo).state, const AuthState.unknown());
  });

  blocTest<AuthBloc, AuthState>(
    'maps the user stream to authenticated / unauthenticated',
    setUp: () => when(() => repo.user).thenAnswer((_) => Stream.fromIterable([user, null])),
    build: () => AuthBloc(authRepository: repo),
    act: (b) => b.add(const AuthSubscriptionRequested()),
    expect: () => [const AuthState.authenticated(user), const AuthState.unauthenticated()],
  );

  blocTest<AuthBloc, AuthState>(
    'logout calls the repository',
    setUp: () => when(() => repo.logOut()).thenAnswer((_) async {}),
    build: () => AuthBloc(authRepository: repo),
    act: (b) => b.add(const AuthLogoutPressed()),
    verify: (_) => verify(() => repo.logOut()).called(1),
  );
}
