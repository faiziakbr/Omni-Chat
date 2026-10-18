import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/app_user.dart';
import '../data/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required this._authRepository}) : super(const AuthState.unknown()) {
    on<AuthSubscriptionRequested>(_onSubscriptionRequested, transformer: restartable());
    on<AuthLogoutPressed>(_onLogoutPressed, transformer: droppable());
  }

  final AuthRepository _authRepository;

  Future<void> _onSubscriptionRequested(AuthSubscriptionRequested event, Emitter<AuthState> emit) =>
      emit.forEach<AppUser?>(
        _authRepository.user,
        onData: (user) =>
            user == null ? const AuthState.unauthenticated() : AuthState.authenticated(user),
        onError: (_, _) => const AuthState.unauthenticated(),
      );

  Future<void> _onLogoutPressed(AuthLogoutPressed event, Emitter<AuthState> emit) =>
      _authRepository.logOut();
}
