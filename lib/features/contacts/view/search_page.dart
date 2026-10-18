import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/data/app_user.dart';
import '../../auth/view/auth_scaffold.dart' show validateEmail;
import '../bloc/user_search_bloc.dart';
import '../data/contact.dart';
import '../data/user_repository.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => UserSearchBloc(
        userRepository: context.read<UserRepository>(),
        me: context.read<AppUser>(),
      ),
      child: const SearchView(),
    );
  }
}

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<UserSearchBloc>().add(UserSearchSubmitted(_email.text));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserSearchBloc, UserSearchState>(
      listenWhen: (p, c) => p.status != c.status && c.status == UserSearchStatus.linked,
      listener: (context, state) {
        final peer = state.result!;
        context.pushReplacement('/chat/${peer.uid}', extra: Contact.fromUser(peer));
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('New chat')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _email,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.search,
                    onFieldSubmitted: (_) => _submit(),
                    validator: validateEmail,
                    decoration: InputDecoration(
                      hintText: 'Search by email address',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.all(6),
                        child: IconButton.filled(
                          tooltip: 'Search',
                          icon: Icon(
                            Icons.arrow_forward,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          onPressed: _submit,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                BlocBuilder<UserSearchBloc, UserSearchState>(
                  builder: (context, state) => switch (state.status) {
                    UserSearchStatus.initial => const _Hint(
                      icon: Icons.person_search_rounded,
                      title: 'Find a friend',
                      text: 'Enter the exact email your friend signed up with.',
                    ),
                    UserSearchStatus.searching => const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    UserSearchStatus.notFound => const _Hint(
                      icon: Icons.search_off_rounded,
                      title: 'No one found',
                      text: 'Check the spelling, or ask your friend to create an account first.',
                    ),
                    UserSearchStatus.failure => _Hint(
                      icon: Icons.error_outline_rounded,
                      title: 'Search failed',
                      text: state.error ?? 'Something went wrong. Try again.',
                    ),
                    UserSearchStatus.found ||
                    UserSearchStatus.linking ||
                    UserSearchStatus.linked => _ResultCard(
                      user: state.result!,
                      busy: state.status != UserSearchStatus.found,
                    ),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.user, required this.busy});
  final AppUser user;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            UserAvatar(name: user.name, radius: 40),
            const SizedBox(height: 16),
            Text(user.name, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              user.email,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => context.read<UserSearchBloc>().add(const UserSearchStartChatPressed()),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Start chatting'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: EmptyState(icon: icon, title: title, text: text),
  );
}
