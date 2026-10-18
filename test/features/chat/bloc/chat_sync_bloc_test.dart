import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omni_chat/features/chat/bloc/chat_sync_bloc.dart';
import 'package:omni_chat/features/chat/data/chat_repository.dart';
import 'package:omni_chat/features/chat/data/local/app_database.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

void main() {
  const m1 = IncomingMessage(id: '1', senderId: 'bob', text: 'hi', sentAt: 1);
  const m2 = IncomingMessage(id: '2', senderId: 'bob', text: 'yo', sentAt: 2);
  const r1 = Receipt(messageId: 'x', status: MessageStatus.read);
  late _MockChatRepository repo;

  setUpAll(() {
    registerFallbackValue(m1);
    registerFallbackValue(r1);
  });

  setUp(() {
    repo = _MockChatRepository();
    when(() => repo.incomingMessages()).thenAnswer((_) => const Stream.empty());
    when(() => repo.receipts()).thenAnswer((_) => const Stream.empty());
    when(() => repo.ingest(any())).thenAnswer((_) async {});
    when(() => repo.applyReceipt(any())).thenAnswer((_) async {});
  });

  blocTest<ChatSyncBloc, ChatSyncState>(
    'ingests every incoming message in order',
    setUp: () =>
        when(() => repo.incomingMessages()).thenAnswer((_) => Stream.fromIterable([m1, m2])),
    build: () => ChatSyncBloc(chatRepository: repo),
    act: (b) => b.add(const ChatSyncStarted()),
    expect: () => const [
      ChatSyncState(status: ChatSyncStatus.syncing),
      ChatSyncState(status: ChatSyncStatus.syncing, received: 1),
      ChatSyncState(status: ChatSyncStatus.syncing, received: 2),
    ],
    verify: (_) {
      verifyInOrder([() => repo.ingest(m1), () => repo.ingest(m2)]);
    },
  );

  blocTest<ChatSyncBloc, ChatSyncState>(
    'applies receipts',
    setUp: () => when(() => repo.receipts()).thenAnswer((_) => Stream.value(r1)),
    build: () => ChatSyncBloc(chatRepository: repo),
    act: (b) => b.add(const ChatSyncStarted()),
    verify: (_) => verify(() => repo.applyReceipt(r1)).called(1),
  );

  blocTest<ChatSyncBloc, ChatSyncState>(
    'reports failure when ingest throws',
    setUp: () {
      when(() => repo.incomingMessages()).thenAnswer((_) => Stream.value(m1));
      when(() => repo.ingest(any())).thenThrow(Exception('offline'));
    },
    build: () => ChatSyncBloc(chatRepository: repo),
    act: (b) => b.add(const ChatSyncStarted()),
    expect: () => [
      const ChatSyncState(status: ChatSyncStatus.syncing),
      isA<ChatSyncState>().having((s) => s.status, 'status', ChatSyncStatus.failure),
    ],
  );
}
