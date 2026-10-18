import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omni_chat/features/auth/bloc/auth_form_bloc.dart';
import 'package:omni_chat/features/auth/data/auth_repository.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repo;

  setUp(() => repo = _MockAuthRepository());

  blocTest<AuthFormBloc, AuthFormState>(
    'login success emits [submitting, success]',
    setUp: () =>
        when(() => repo.logIn(email: 'a@b.co', password: 'secret')).thenAnswer((_) async {}),
    build: () => AuthFormBloc(authRepository: repo),
    act: (b) => b.add(const LoginSubmitted(email: 'a@b.co', password: 'secret')),
    expect: () => const [
      AuthFormState(status: AuthFormStatus.submitting),
      AuthFormState(status: AuthFormStatus.success),
    ],
  );

  blocTest<AuthFormBloc, AuthFormState>(
    'login failure emits the failure message',
    setUp: () => when(
      () => repo.logIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const AuthFailure('Incorrect email or password.')),
    build: () => AuthFormBloc(authRepository: repo),
    act: (b) => b.add(const LoginSubmitted(email: 'a@b.co', password: 'bad')),
    expect: () => const [
      AuthFormState(status: AuthFormStatus.submitting),
      AuthFormState(status: AuthFormStatus.failure, error: 'Incorrect email or password.'),
    ],
  );

  blocTest<AuthFormBloc, AuthFormState>(
    'register success emits [submitting, success]',
    setUp: () =>
        when(() => repo.register(name: 'Ann', email: 'a@b.co', password: 'secret'))
            .thenAnswer((_) async {}),
    build: () => AuthFormBloc(authRepository: repo),
    act: (b) => b.add(const RegisterSubmitted(name: 'Ann', email: 'a@b.co', password: 'secret')),
    expect: () => const [
      AuthFormState(status: AuthFormStatus.submitting),
      AuthFormState(status: AuthFormStatus.success),
    ],
  );
}
