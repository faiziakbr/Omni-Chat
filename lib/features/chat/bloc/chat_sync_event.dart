part of 'chat_sync_bloc.dart';

sealed class ChatSyncEvent extends Equatable {
  const ChatSyncEvent();
  @override
  List<Object?> get props => [];
}

final class ChatSyncStarted extends ChatSyncEvent {
  const ChatSyncStarted();
}

final class _IncomingReceived extends ChatSyncEvent {
  const _IncomingReceived(this.message);
  final IncomingMessage message;
  @override
  List<Object?> get props => [message];
}

final class _ReceiptReceived extends ChatSyncEvent {
  const _ReceiptReceived(this.receipt);
  final Receipt receipt;
  @override
  List<Object?> get props => [receipt];
}
