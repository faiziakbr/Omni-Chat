import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme.dart';
import '../../../core/time_format.dart';
import '../../../core/widgets/empty_state.dart';
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: Color.alphaBlend(scheme.primary.withValues(alpha: 0.035), scheme.surface),
      appBar: AppBar(
        titleSpacing: 0,
        title: BlocBuilder<ChatBloc, ChatState>(
          buildWhen: (p, c) => p.peer != c.peer || p.peerPresence != c.peerPresence,
          builder: (context, state) {
            final online = state.peerPresence.online;
            return Row(
              children: [
                UserAvatar(name: state.peer?.name ?? '', online: online, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.peer?.name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        online ? 'online' : formatLastSeen(state.peerPresence.lastSeen),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: online ? AppTheme.online : scheme.onSurfaceVariant,
                          fontWeight: online ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: const [_VideoCallButton(), SizedBox(width: 12)],
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
    return IconButton.filledTonal(
      tooltip: offline ? "Can't call while offline" : 'Video call',
      icon: const Icon(Icons.videocam_rounded),
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
          return EmptyState(
            icon: Icons.error_outline_rounded,
            title: "Couldn't load messages",
            text: state.error ?? 'Something went wrong.',
          );
        }
        if (state.messages.isEmpty) {
          return EmptyState(
            icon: Icons.waving_hand_outlined,
            title: 'Say hi to ${state.peer?.name ?? 'them'}',
            text: 'Send a message or start a video call.',
          );
        }
        final messages = state.messages.reversed.toList();
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          itemCount: messages.length,
          itemBuilder: (context, i) {
            final m = messages[i];
            final older = i + 1 < messages.length ? messages[i + 1] : null;
            final showDay = older == null || !_sameDay(older.time, m.time);
            final groupStart = showDay || older.isMine != m.isMine || older.kind != m.kind;
            return Column(
              children: [
                if (showDay) _DayChip(m.time),
                Padding(
                  padding: EdgeInsets.only(top: groupStart ? 8 : 0),
                  child: _Bubble(message: m),
                ),
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
    final theme = Theme.of(context);
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mine = message.isMine;
    final failed = message.status == MessageStatus.failed;

    if (message.kind == MessageKind.call) return _CallLog(message: message);

    final textColor = mine ? Colors.white : scheme.onSurface;
    final metaColor = mine ? Colors.white.withValues(alpha: 0.75) : scheme.onSurfaceVariant;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
      margin: const EdgeInsets.symmetric(vertical: 1.5),
      padding: const EdgeInsets.fromLTRB(14, 9, 12, 7),
      decoration: BoxDecoration(
        gradient: mine ? AppTheme.brandGradient : null,
        color: mine ? null : AppTheme.raised(scheme),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(mine ? 20 : 6),
          bottomRight: Radius.circular(mine ? 6 : 20),
        ),
        boxShadow: [
          BoxShadow(
            color: mine
                ? const Color(0xFF4F46E5).withValues(alpha: 0.18)
                : scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            message.body,
            style: theme.textTheme.bodyLarge?.copyWith(color: textColor, height: 1.3),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(formatClock(message.time), style: TextStyle(fontSize: 11, color: metaColor)),
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
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.read<ChatBloc>().add(ChatRetryPressed(message.id)),
              child: Tooltip(message: 'Not sent. Tap to retry.', child: bubble),
            )
          : bubble,
    );
  }
}

/// Centered pill for call events ("Outgoing video call · 3:12", "Missed video call").
class _CallLog extends StatelessWidget {
  const _CallLog({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Connected calls carry a duration ("… · 3:12"); everything else didn't connect.
    final connected = message.body.contains('·');
    final accent = connected ? scheme.primary : scheme.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
          decoration: BoxDecoration(
            color: AppTheme.raised(scheme),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: accent.withValues(alpha: 0.12),
                child: Icon(
                  connected ? Icons.videocam_rounded : Icons.missed_video_call_rounded,
                  size: 16,
                  color: accent,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.body,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatClock(message.time),
                style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon(this.status);
  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final muted = Colors.white.withValues(alpha: 0.75);
    final (icon, color, label) = switch (status) {
      MessageStatus.pending => (Icons.schedule, muted, 'Sending'),
      MessageStatus.failed => (Icons.error_outline, const Color(0xFFFFB4AB), 'Not sent'),
      MessageStatus.sent => (Icons.done, muted, 'Sent'),
      MessageStatus.delivered => (Icons.done_all, muted, 'Delivered'),
      MessageStatus.read => (Icons.done_all, const Color(0xFF7DF9FF), 'Read'),
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
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
              decoration: InputDecoration(
                hintText: 'Message',
                counterText: '',
                isDense: true,
                filled: true,
                fillColor: AppTheme.raised(scheme),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(24)),
                  borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(24)),
                  borderSide: BorderSide(color: scheme.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, value, _) {
              final canSend = ready && value.text.trim().isNotEmpty;
              return _SendButton(onPressed: canSend ? _send : null);
            },
          ),
        ],
      ),
    );
  }
}

/// Round gradient send button; greys out when there's nothing to send.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return Tooltip(
      message: 'Send',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: enabled ? AppTheme.brandGradient : null,
          color: enabled ? null : scheme.surfaceContainerHighest,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Icon(
              Icons.send_rounded,
              size: 22,
              color: enabled ? Colors.white : scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
