import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/time_format.dart';
import '../../../core/widgets/empty_state.dart';
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 20,
        title: Text('Chats', style: theme.textTheme.headlineMedium),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Account',
            offset: const Offset(0, 52),
            icon: UserAvatar(name: me.name, radius: 18),
            onSelected: (v) {
              if (v == 'logout') context.read<AuthBloc>().add(const AuthLogoutPressed());
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: UserAvatar(name: me.name, radius: 20),
                  title: Text(me.name, style: theme.textTheme.titleMedium),
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
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/search'),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('New chat'),
      ),
      body: BlocBuilder<ContactsBloc, ContactsState>(
        builder: (context, state) {
          switch (state.status) {
            case ContactsStatus.initial:
            case ContactsStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case ContactsStatus.failure:
              return const EmptyState(
                icon: Icons.cloud_off_rounded,
                title: "Couldn't load your chats",
                text: 'Check your connection and try again.',
              );
            case ContactsStatus.success:
              if (state.contacts.isEmpty) {
                return EmptyState(
                  icon: Icons.forum_rounded,
                  title: 'No chats yet',
                  text: 'Find a friend by their email to start chatting and video calling.',
                  action: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: () => context.push('/search'),
                    icon: const Icon(Icons.person_search_outlined),
                    label: const Text('Find someone'),
                  ),
                );
              }
              final contacts = state.sortedContacts;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 96),
                    itemCount: contacts.length,
                    itemBuilder: (context, i) {
                      final c = contacts[i];
                      return _ContactTile(
                        contact: c,
                        online: state.isOnline(c.uid),
                        summary: state.summaries[c.uid],
                        lastSeen: state.presence[c.uid]?.lastSeen,
                      );
                    },
                  ),
                ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final last = summary?.last;
    final unread = summary?.unread ?? 0;
    final subtitle = switch (last) {
      null => online ? 'online' : formatLastSeen(lastSeen),
      ChatMessage(isMine: true, kind: MessageKind.text) => 'You: ${last.body}',
      _ => last.body,
    };
    final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: unread > 0 ? scheme.onSurface : scheme.onSurfaceVariant,
      fontWeight: unread > 0 ? FontWeight.w600 : null,
    );
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/chat/${contact.uid}', extra: contact),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            UserAvatar(name: contact.name, online: online, radius: 27),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          contact.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (last != null)
                        Text(
                          formatClock(last.time),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: unread > 0 ? scheme.primary : scheme.onSurfaceVariant,
                            fontWeight: unread > 0 ? FontWeight.w700 : null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (last?.kind == MessageKind.call) ...[
                        Icon(Icons.videocam_outlined, size: 16, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: subtitleStyle,
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          constraints: const BoxConstraints(minWidth: 22),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: AppTheme.brandGradient,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
