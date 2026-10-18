part of 'chat_bloc.dart';

sealed class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

final class ChatSubscriptionRequested extends ChatEvent {
  const ChatSubscriptionRequested();
}

final class ChatMessageSubmitted extends ChatEvent {
  const ChatMessageSubmitted(this.text);
  final String text;
  @override
  List<Object?> get props => [text];
}

final class ChatRetryPressed extends ChatEvent {
  const ChatRetryPressed(this.messageId);
  final String messageId;
  @override
  List<Object?> get props => [messageId];
}

final class _UnreadDetected extends ChatEvent {
  const _UnreadDetected();
}
