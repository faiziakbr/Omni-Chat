import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
        appBar: AppBar(title: const Text('Find someone')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(16),
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
                      labelText: 'Email address',
                      hintText: 'friend@example.com',
                      suffixIcon: IconButton(
                        tooltip: 'Search',
                        icon: const Icon(Icons.search),
                        onPressed: _submit,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                BlocBuilder<UserSearchBloc, UserSearchState>(
                  builder: (context, state) => switch (state.status) {
                    UserSearchStatus.initial => const _Hint(
                      'Enter the exact email your friend registered with.',
                    ),
                    UserSearchStatus.searching => const Center(child: CircularProgressIndicator()),
                    UserSearchStatus.notFound => const _Hint('No user with that email.'),
                    UserSearchStatus.failure => _Hint(state.error ?? 'Search failed.'),
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
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: UserAvatar(name: user.name),
        title: Text(user.name),
        subtitle: Text(user.email),
        trailing: FilledButton.tonalIcon(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: busy
              ? null
              : () => context.read<UserSearchBloc>().add(const UserSearchStartChatPressed()),
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Message'),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}
