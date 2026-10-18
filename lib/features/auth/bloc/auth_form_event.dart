part of 'auth_form_bloc.dart';

sealed class AuthFormEvent extends Equatable {
  const AuthFormEvent();
  @override
  List<Object?> get props => [];
}

final class LoginSubmitted extends AuthFormEvent {
  const LoginSubmitted({required this.email, required this.password});
  final String email;
  final String password;
  @override
  List<Object?> get props => [email, password];
}

final class RegisterSubmitted extends AuthFormEvent {
  const RegisterSubmitted({required this.name, required this.email, required this.password});
  final String name;
  final String email;
  final String password;
  @override
  List<Object?> get props => [name, email, password];
}
