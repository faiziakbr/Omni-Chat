part of 'chat_sync_bloc.dart';

enum ChatSyncStatus { idle, syncing, failure }

final class ChatSyncState extends Equatable {
  const ChatSyncState({this.status = ChatSyncStatus.idle, this.received = 0, this.error});

  final ChatSyncStatus status;

  /// Messages synced this session (lets listeners react to new arrivals).
  final int received;
  final String? error;

  ChatSyncState copyWith({ChatSyncStatus? status, int? received, String? error}) => ChatSyncState(
    status: status ?? this.status,
    received: received ?? this.received,
    error: error,
  );

  @override
  List<Object?> get props => [status, received, error];
}
