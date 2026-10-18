import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../contacts/data/contact.dart';
import '../../contacts/data/user_repository.dart';
import '../../presence/data/presence.dart';
import '../../presence/data/presence_repository.dart';
import '../data/chat_repository.dart';
import '../data/local/app_database.dart';

part 'chat_event.dart';
part 'chat_state.dart';

/// One open conversation.
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({
    required this._chatRepository,
    required this._presenceRepository,
    required this._userRepository,
    required String peerId,
    Contact? peer,
  }) : super(ChatState(peerId: peerId, peer: peer)) {
    on<ChatSubscriptionRequested>(_onSubscriptionRequested, transformer: restartable());
    on<ChatMessageSubmitted>(_onMessageSubmitted, transformer: sequential());
    on<ChatRetryPressed>(_onRetryPressed, transformer: sequential());
    // Not droppable: a message that lands while a mark-read is in flight
    // would be skipped and stay unread until the chat is reopened.
    on<_UnreadDetected>(_onUnreadDetected, transformer: sequential());
  }

  final ChatRepository _chatRepository;
  final PresenceRepository _presenceRepository;
  final UserRepository _userRepository;

  Future<void> _onSubscriptionRequested(
    ChatSubscriptionRequested event,
    Emitter<ChatState> emit,
  ) async {
    if (state.peer == null) {
      // Opened by URL (e.g. web refresh) without the contact passed along.
      final user = await _userRepository.getUser(state.peerId);
      if (user == null) {
        emit(state.copyWith(status: ChatStatus.failure, error: 'User not found.'));
        return;
      }
      emit(state.copyWith(peer: Contact.fromUser(user)));
    }
    await Future.wait([
      emit.forEach<List<ChatMessage>>(
        _chatRepository.watchMessages(state.peerId),
        onData: (messages) {
          if (messages.any((m) => !m.isMine && m.status == MessageStatus.delivered)) {
            add(const _UnreadDetected());
          }
          return state.copyWith(status: ChatStatus.ready, messages: messages);
        },
        onError: (_, _) =>
            state.copyWith(status: ChatStatus.failure, error: "Couldn't load messages."),
      ),
      emit.forEach<Presence>(
        _presenceRepository.watch(state.peerId),
        onData: (p) => state.copyWith(peerPresence: p),
        onError: (_, _) => state,
      ),
    ]);
  }

  Future<void> _onMessageSubmitted(ChatMessageSubmitted event, Emitter<ChatState> emit) async {
    final peer = state.peer;
    if (peer == null || event.text.trim().isEmpty) return;
    try {
      await _chatRepository.sendText(peer, event.text);
    } catch (_) {
      // Stored as "failed" locally; the bubble offers a retry.
    }
  }

  Future<void> _onRetryPressed(ChatRetryPressed event, Emitter<ChatState> emit) async {
    final peer = state.peer;
    if (peer == null) return;
    try {
      await _chatRepository.retry(event.messageId, peer);
    } catch (_) {}
  }

  Future<void> _onUnreadDetected(_UnreadDetected event, Emitter<ChatState> emit) async {
    try {
      await _chatRepository.markConversationRead(state.peerId);
    } catch (_) {}
  }
}
