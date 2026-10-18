part of 'chat_bloc.dart';

enum ChatStatus { loading, ready, failure }

final class ChatState extends Equatable {
  const ChatState({
    required this.peerId,
    this.peer,
    this.status = ChatStatus.loading,
    this.messages = const [],
    this.peerPresence = const Presence.offline(),
    this.error,
  });

  final String peerId;
  final Contact? peer;
  final ChatStatus status;
  final List<ChatMessage> messages;
  final Presence peerPresence;
  final String? error;

  ChatState copyWith({
    Contact? peer,
    ChatStatus? status,
    List<ChatMessage>? messages,
    Presence? peerPresence,
    String? error,
  }) => ChatState(
    peerId: peerId,
    peer: peer ?? this.peer,
    status: status ?? this.status,
    messages: messages ?? this.messages,
    peerPresence: peerPresence ?? this.peerPresence,
    error: error,
  );

  @override
  List<Object?> get props => [peerId, peer, status, messages, peerPresence, error];
}
