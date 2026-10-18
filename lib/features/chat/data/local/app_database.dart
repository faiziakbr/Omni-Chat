import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Ordered by progress; a status never moves backwards (see [upgradeStatus]).
enum MessageStatus { pending, failed, sent, delivered, read }

enum MessageKind { text, call }

@DataClassName('ChatMessage')
@TableIndex(name: 'idx_messages_peer_time', columns: {#peerId, #sentAt})
class ChatMessages extends Table {
  TextColumn get id => text()();

  /// The other person in the 1v1 conversation.
  TextColumn get peerId => text()();
  TextColumn get senderId => text()();
  TextColumn get body => text()();

  /// Milliseconds since epoch. Server time for incoming, local time for outgoing.
  IntColumn get sentAt => integer()();
  TextColumn get status => textEnum<MessageStatus>()();
  TextColumn get kind => textEnum<MessageKind>().withDefault(const Constant('text'))();
  BoolColumn get isMine => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

extension ChatMessageX on ChatMessage {
  DateTime get time => DateTime.fromMillisecondsSinceEpoch(sentAt);
}

/// Last message + unread count for one conversation (home list).
class ConversationSummary {
  const ConversationSummary({required this.last, required this.unread});
  final ChatMessage last;
  final int unread;
}

@DriftDatabase(tables: [ChatMessages])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// One database per signed-in user so accounts never share history.
  AppDatabase.forUser(String uid)
    : super(
        driftDatabase(
          name: 'omni_chat_$uid',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  @override
  int get schemaVersion => 1;

  Stream<List<ChatMessage>> watchConversation(String peerId) =>
      (select(chatMessages)
            ..where((m) => m.peerId.equals(peerId))
            ..orderBy([(m) => OrderingTerm.asc(m.sentAt)]))
          .watch();

  Future<ChatMessage?> messageById(String id) =>
      (select(chatMessages)..where((m) => m.id.equals(id))).getSingleOrNull();

  /// Idempotent: re-delivering the same message id is a no-op.
  Future<void> insertIfAbsent(ChatMessagesCompanion message) =>
      into(chatMessages).insert(message, mode: InsertMode.insertOrIgnore);

  Future<void> setStatus(String id, MessageStatus status) => (update(
    chatMessages,
  )..where((m) => m.id.equals(id))).write(ChatMessagesCompanion(status: Value(status)));

  /// Moves [id] to [status] only if that's forward progress.
  Future<void> upgradeStatus(String id, MessageStatus status) {
    final lower = MessageStatus.values.where((s) => s.index < status.index).map((s) => s.name);
    return (update(chatMessages)..where((m) => m.id.equals(id) & m.status.isIn(lower))).write(
      ChatMessagesCompanion(status: Value(status)),
    );
  }

  Future<List<ChatMessage>> unreadIncoming(String peerId) =>
      (select(chatMessages)..where(
            (m) =>
                m.peerId.equals(peerId) &
                m.isMine.equals(false) &
                m.status.equalsValue(MessageStatus.delivered),
          ))
          .get();

  Future<void> markRead(Iterable<String> ids) =>
      (update(chatMessages)..where((m) => m.id.isIn(ids))).write(
        const ChatMessagesCompanion(status: Value(MessageStatus.read)),
      );

  Stream<Map<String, ConversationSummary>> watchSummaries() {
    return customSelect(
      'SELECT m.*, '
      '(SELECT COUNT(*) FROM chat_messages u '
      " WHERE u.peer_id = m.peer_id AND u.is_mine = 0 AND u.status = 'delivered') AS unread "
      'FROM chat_messages m '
      'WHERE m.sent_at = (SELECT MAX(x.sent_at) FROM chat_messages x WHERE x.peer_id = m.peer_id) '
      'GROUP BY m.peer_id',
      readsFrom: {chatMessages},
    ).watch().map(
      (rows) => {
        for (final row in rows)
          row.read<String>('peer_id'): ConversationSummary(
            last: chatMessages.map(row.data),
            unread: row.read<int>('unread'),
          ),
      },
    );
  }
}
