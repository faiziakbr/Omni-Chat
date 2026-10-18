import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/chat_repository.dart';

part 'chat_sync_event.dart';
part 'chat_sync_state.dart';

/// Session-wide: drains my RTDB inbox into the local DB and applies receipts,
/// whatever screen is open.
class ChatSyncBloc extends Bloc<ChatSyncEvent, ChatSyncState> {
  ChatSyncBloc({required this._chatRepository}) : super(const ChatSyncState()) {
    on<ChatSyncStarted>(_onStarted, transformer: restartable());
    on<_IncomingReceived>(_onIncoming, transformer: sequential());
    on<_ReceiptReceived>(_onReceipt, transformer: sequential());
  }

  final ChatRepository _chatRepository;

  Future<void> _onStarted(ChatSyncStarted event, Emitter<ChatSyncState> emit) async {
    emit(state.copyWith(status: ChatSyncStatus.syncing));
    await Future.wait([
      emit.onEach<IncomingMessage>(
        _chatRepository.incomingMessages(),
        onData: (m) => add(_IncomingReceived(m)),
        onError: (e, _) => emit(state.copyWith(status: ChatSyncStatus.failure, error: '$e')),
      ),
      emit.onEach<Receipt>(
        _chatRepository.receipts(),
        onData: (r) => add(_ReceiptReceived(r)),
        onError: (e, _) => emit(state.copyWith(status: ChatSyncStatus.failure, error: '$e')),
      ),
    ]);
  }

  Future<void> _onIncoming(_IncomingReceived event, Emitter<ChatSyncState> emit) async {
    try {
      await _chatRepository.ingest(event.message);
      emit(state.copyWith(status: ChatSyncStatus.syncing, received: state.received + 1));
    } catch (e) {
      // Left in RTDB; it'll be retried on the next start.
      emit(state.copyWith(status: ChatSyncStatus.failure, error: '$e'));
    }
  }

  Future<void> _onReceipt(_ReceiptReceived event, Emitter<ChatSyncState> emit) async {
    try {
      await _chatRepository.applyReceipt(event.receipt);
    } catch (e) {
      emit(state.copyWith(status: ChatSyncStatus.failure, error: '$e'));
    }
  }
}
