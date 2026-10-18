import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/time_format.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/data/app_user.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/data/local/app_database.dart';
import '../../presence/data/presence_repository.dart';
import '../bloc/contacts_bloc.dart';
import '../data/contact.dart';
import '../data/user_repository.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ContactsBloc(
        userRepository: context.read<UserRepository>(),
        presenceRepository: context.read<PresenceRepository>(),
        chatRepository: context.read<ChatRepository>(),
        uid: context.read<AppUser>().uid,
      )..add(const ContactsSubscriptionRequested()),
      child: const HomeView(),
    );
  }
}

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.read<AppUser>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Omni Chat'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Account',
            icon: UserAvatar(name: me.name, radius: 16),
            onSelected: (v) {
              if (v == 'logout') context.read<AuthBloc>().add(const AuthLogoutPressed());
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(me.name),
                  subtitle: Text(me.email),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout),
                  title: Text('Log out'),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/search'),
        icon: const Icon(Icons.person_search),
        label: const Text('New chat'),
      ),
      body: BlocBuilder<ContactsBloc, ContactsState>(
        builder: (context, state) {
          switch (state.status) {
            case ContactsStatus.initial:
            case ContactsStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case ContactsStatus.failure:
              return const _Empty(
                icon: Icons.cloud_off,
                text: "Couldn't load your chats. Check your connection.",
              );
            case ContactsStatus.success:
              if (state.contacts.isEmpty) {
                return const _Empty(
                  icon: Icons.forum_outlined,
                  text: 'No chats yet.\nTap "New chat" to find someone by email.',
                );
              }
              final contacts = state.sortedContacts;
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: contacts.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                itemBuilder: (context, i) {
                  final c = contacts[i];
                  return _ContactTile(
                    contact: c,
                    online: state.isOnline(c.uid),
                    summary: state.summaries[c.uid],
                    lastSeen: state.presence[c.uid]?.lastSeen,
                  );
                },
              );
          }
        },
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.online,
    required this.summary,
    required this.lastSeen,
  });

  final Contact contact;
  final bool online;
  final ConversationSummary? summary;
  final DateTime? lastSeen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = summary?.last;
    final unread = summary?.unread ?? 0;
    final subtitle = switch (last) {
      null => online ? 'online' : formatLastSeen(lastSeen),
      ChatMessage(kind: MessageKind.call) => '📹 ${last.body}',
      ChatMessage(isMine: true) => 'You: ${last.body}',
      _ => last.body,
    };
    return ListTile(
      leading: UserAvatar(name: contact.name, online: online),
      title: Text(contact.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: unread > 0 ? const TextStyle(fontWeight: FontWeight.w600) : null,
      ),
      trailing: last == null
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatClock(last.time),
                  style: TextStyle(
                    fontSize: 12,
                    color: unread > 0 ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                if (unread > 0) Badge.count(count: unread, backgroundColor: scheme.primary),
              ],
            ),
      onTap: () => context.push('/chat/${contact.uid}', extra: contact),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
