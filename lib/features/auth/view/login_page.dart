import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/auth_form_bloc.dart';
import '../data/auth_repository.dart';
import 'auth_scaffold.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthFormBloc(authRepository: context.read<AuthRepository>()),
      child: const LoginView(),
    );
  }
}

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthFormBloc>().add(LoginSubmitted(email: _email.text, password: _password.text));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthFormBloc, AuthFormState>(
      listenWhen: (p, c) => c.status == AuthFormStatus.failure,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(state.error ?? 'Login failed'))),
      child: AuthScaffold(
        title: 'Welcome back',
        subtitle: 'Log in to chat and video call your friends.',
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: validateEmail,
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _password,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: _submit,
                ),
                const SizedBox(height: 24),
                BlocSelector<AuthFormBloc, AuthFormState, bool>(
                  selector: (s) => s.isSubmitting,
                  builder: (context, submitting) =>
                      SubmitButton(label: 'Log in', busy: submitting, onPressed: _submit),
                ),
                const SizedBox(height: 12),
                SwitchLink(
                  prompt: "Don't have an account?",
                  action: 'Create one',
                  onPressed: () => context.go('/register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
