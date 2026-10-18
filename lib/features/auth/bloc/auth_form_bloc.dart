import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/auth_repository.dart';

part 'auth_form_event.dart';
part 'auth_form_state.dart';

/// Handles login and register submission. Field validation lives in the form.
class AuthFormBloc extends Bloc<AuthFormEvent, AuthFormState> {
  AuthFormBloc({required this._authRepository}) : super(const AuthFormState()) {
    on<LoginSubmitted>(_onLoginSubmitted, transformer: droppable());
    on<RegisterSubmitted>(_onRegisterSubmitted, transformer: droppable());
  }

  final AuthRepository _authRepository;

  Future<void> _onLoginSubmitted(LoginSubmitted event, Emitter<AuthFormState> emit) =>
      _run(emit, () => _authRepository.logIn(email: event.email, password: event.password));

  Future<void> _onRegisterSubmitted(RegisterSubmitted event, Emitter<AuthFormState> emit) => _run(
    emit,
    () => _authRepository.register(name: event.name, email: event.email, password: event.password),
  );

  Future<void> _run(Emitter<AuthFormState> emit, Future<void> Function() action) async {
    emit(const AuthFormState(status: AuthFormStatus.submitting));
    try {
      await action();
      emit(const AuthFormState(status: AuthFormStatus.success));
    } on AuthFailure catch (e) {
      emit(AuthFormState(status: AuthFormStatus.failure, error: e.message));
    } catch (_) {
      emit(const AuthFormState(status: AuthFormStatus.failure, error: 'Something went wrong.'));
    }
  }
}
