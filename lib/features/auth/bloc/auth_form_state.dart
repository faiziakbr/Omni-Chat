part of 'auth_form_bloc.dart';

enum AuthFormStatus { initial, submitting, success, failure }

final class AuthFormState extends Equatable {
  const AuthFormState({this.status = AuthFormStatus.initial, this.error});

  final AuthFormStatus status;
  final String? error;

  bool get isSubmitting => status == AuthFormStatus.submitting;

  @override
  List<Object?> get props => [status, error];
}
