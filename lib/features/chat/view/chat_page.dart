import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/time_format.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../call/bloc/call_bloc.dart';
import '../../connectivity/bloc/connectivity_bloc.dart';
import '../../contacts/data/contact.dart';
import '../../contacts/data/user_repository.dart';
import '../../presence/data/presence_repository.dart';
import '../bloc/chat_bloc.dart';
import '../data/chat_repository.dart';
import '../data/local/app_database.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key, required this.peerId, this.peer});

  final String peerId;
  final Contact? peer;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatBloc(
        chatRepository: context.read<ChatRepository>(),
        presenceRepository: context.read<PresenceRepository>(),
        userRepository: context.read<UserRepository>(),
        peerId: peerId,
        peer: peer,
      )..add(const ChatSubscriptionRequested()),
      child: const ChatView(),
    );
  }
}

class ChatView extends StatelessWidget {
  const ChatView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: BlocBuilder<ChatBloc, ChatState>(
          buildWhen: (p, c) => p.peer != c.peer || p.peerPresence != c.peerPresence,
          builder: (context, state) {
            final online = state.peerPresence.online;
            return Row(
              children: [
                UserAvatar(name: state.peer?.name ?? '', online: online, radius: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.peer?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        online ? 'online' : formatLastSeen(state.peerPresence.lastSeen),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: const [_VideoCallButton(), SizedBox(width: 8)],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: const Column(
              children: [
                Expanded(child: _MessageList()),
                _Composer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoCallButton extends StatelessWidget {
  const _VideoCallButton();

  @override
  Widget build(BuildContext context) {
    final peer = context.select((ChatBloc b) => b.state.peer);
    final busy = context.select((CallBloc b) => b.state.inCall);
    final offline = context.select((ConnectivityBloc b) => b.state.isOffline);
    return IconButton(
      tooltip: offline ? "Can't call while offline" : 'Video call',
      icon: const Icon(Icons.videocam_outlined),
      onPressed: peer == null || busy || offline
          ? null
          : () => context.read<CallBloc>().add(CallStarted(peer)),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      buildWhen: (p, c) => p.messages != c.messages || p.status != c.status,
      builder: (context, state) {
        if (state.status == ChatStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == ChatStatus.failure) {
          return Center(child: Text(state.error ?? 'Something went wrong.'));
        }
        if (state.messages.isEmpty) {
          return Center(
            child: Text(
              'Say hi to ${state.peer?.name ?? 'them'} 👋',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          );
        }
        final messages = state.messages.reversed.toList();
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: messages.length,
          itemBuilder: (context, i) {
            final m = messages[i];
            final older = i + 1 < messages.length ? messages[i + 1] : null;
            final showDay = older == null || !_sameDay(older.time, m.time);
            return Column(
              children: [
                if (showDay) _DayChip(m.time),
                _Bubble(message: m),
              ],
            );
          },
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayChip extends StatelessWidget {
  const _DayChip(this.day);
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(day.year, day.month, day.day);
    final label = switch (today.difference(d).inDays) {
      0 => 'Today',
      1 => 'Yesterday',
      _ => '${day.day}/${day.month}/${day.year}',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Chip(label: Text(label), visualDensity: VisualDensity.compact),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = message.isMine;
    final failed = message.status == MessageStatus.failed;

    if (message.kind == MessageKind.call) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_outlined, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              '${message.body} · ${formatClock(message.time)}',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
      decoration: BoxDecoration(
        color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            message.body,
            style: TextStyle(color: mine ? scheme.onPrimaryContainer : scheme.onSurface),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatClock(message.time),
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
              if (mine) ...[const SizedBox(width: 4), _StatusIcon(message.status)],
            ],
          ),
        ],
      ),
    );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: failed
          ? InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.read<ChatBloc>().add(ChatRetryPressed(message.id)),
              child: Tooltip(message: 'Not sent. Tap to retry.', child: bubble),
            )
          : bubble,
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon(this.status);
  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, label) = switch (status) {
      MessageStatus.pending => (Icons.schedule, scheme.onSurfaceVariant, 'Sending'),
      MessageStatus.failed => (Icons.error_outline, scheme.error, 'Not sent'),
      MessageStatus.sent => (Icons.done, scheme.onSurfaceVariant, 'Sent'),
      MessageStatus.delivered => (Icons.done_all, scheme.onSurfaceVariant, 'Delivered'),
      MessageStatus.read => (Icons.done_all, Colors.lightBlue, 'Read'),
    };
    return Icon(icon, size: 15, color: color, semanticLabel: label);
  }
}

class _Composer extends StatefulWidget {
  const _Composer();

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _controller = TextEditingController();
  late final _focus = FocusNode(onKeyEvent: _onKey);

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Enter sends, Shift+Enter inserts a newline (desktop/web keyboards).
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<ChatBloc>().add(ChatMessageSubmitted(text));
    _controller.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final ready = context.select((ChatBloc b) => b.state.peer != null);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              enabled: ready,
              minLines: 1,
              maxLines: 5,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Message',
                counterText: '',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, value, _) => IconButton.filled(
              tooltip: 'Send',
              onPressed: ready && value.text.trim().isNotEmpty ? _send : null,
              icon: const Icon(Icons.send),
            ),
          ),
        ],
      ),
    );
  }
}
