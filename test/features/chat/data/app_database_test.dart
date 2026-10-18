import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_chat/features/chat/data/local/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  ChatMessagesCompanion msg(
    String id, {
    String peer = 'bob',
    bool mine = false,
    int at = 1,
    MessageStatus status = MessageStatus.delivered,
  }) => ChatMessagesCompanion.insert(
    id: id,
    peerId: peer,
    senderId: mine ? 'me' : peer,
    body: 'body $id',
    sentAt: at,
    status: status,
    isMine: mine,
  );

  test('insertIfAbsent is idempotent and keeps the first copy', () async {
    await db.insertIfAbsent(msg('1'));
    await db.markRead(['1']);
    await db.insertIfAbsent(msg('1')); // re-delivery
    final m = await db.messageById('1');
    expect(m!.status, MessageStatus.read);
    expect((await db.select(db.chatMessages).get()).length, 1);
  });

  test('upgradeStatus only moves forward', () async {
    await db.insertIfAbsent(msg('1', mine: true, status: MessageStatus.sent));
    await db.upgradeStatus('1', MessageStatus.read);
    await db.upgradeStatus('1', MessageStatus.delivered); // late "delivered" receipt
    expect((await db.messageById('1'))!.status, MessageStatus.read);
  });

  test('unreadIncoming only returns delivered messages from the peer', () async {
    await db.insertIfAbsent(msg('1'));
    await db.insertIfAbsent(msg('2', status: MessageStatus.read));
    await db.insertIfAbsent(msg('3', mine: true, status: MessageStatus.delivered));
    await db.insertIfAbsent(msg('4', peer: 'carol'));
    expect((await db.unreadIncoming('bob')).map((m) => m.id), ['1']);
  });

  test('watchSummaries returns the latest message and unread count per peer', () async {
    await db.insertIfAbsent(msg('1', at: 1));
    await db.insertIfAbsent(msg('2', at: 2));
    await db.insertIfAbsent(msg('3', mine: true, at: 3, status: MessageStatus.sent));
    await db.insertIfAbsent(msg('4', peer: 'carol', at: 5));
    final summaries = await db.watchSummaries().first;
    expect(summaries['bob']!.last.id, '3');
    expect(summaries['bob']!.unread, 2);
    expect(summaries['carol']!.unread, 1);
  });

  test('watchConversation is ordered by time', () async {
    await db.insertIfAbsent(msg('late', at: 10));
    await db.insertIfAbsent(msg('early', at: 5));
    final list = await db.watchConversation('bob').first;
    expect(list.map((m) => m.id), ['early', 'late']);
    expect(list.first.kind, MessageKind.text);
    expect(list.first.status.index, lessThanOrEqualTo(MessageStatus.read.index));
  });

  test('stores MessageKind.call', () async {
    await db.insertIfAbsent(msg('c').copyWith(kind: const Value(MessageKind.call)));
    expect((await db.messageById('c'))!.kind, MessageKind.call);
  });
}
