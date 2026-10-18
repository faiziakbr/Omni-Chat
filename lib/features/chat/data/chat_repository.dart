import 'package:drift/drift.dart' show Value;
import 'package:equatable/equatable.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';

import '../../../core/chat_id.dart';
import '../../../core/merge_streams.dart';
import '../../../core/rtdb_paths.dart';
import '../../auth/data/app_user.dart';
import '../../contacts/data/contact.dart';
import 'local/app_database.dart';

/// A message waiting for me in `inbox/{me}`.
class IncomingMessage extends Equatable {
  const IncomingMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
  });

  static IncomingMessage? tryParse(String? key, Object? value) {
    if (key == null || value is! Map) return null;
    final sender = value['senderId'];
    final text = value['text'];
    if (sender is! String || text is! String) return null;
    final sentAt = value['sentAt'];
    return IncomingMessage(
      id: key,
      senderId: sender,
      text: text,
      sentAt: sentAt is int ? sentAt : DateTime.now().millisecondsSinceEpoch,
    );
  }

  final String id;
  final String senderId;
  final String text;
  final int sentAt;

  @override
  List<Object?> get props => [id, senderId, text, sentAt];
}

/// A delivered/read acknowledgement for a message I sent.
class Receipt extends Equatable {
  const Receipt({required this.messageId, required this.status});

  static Receipt? tryParse(String? key, Object? value) {
    if (key == null || value is! Map) return null;
    final status = switch (value['status']) {
      'delivered' => MessageStatus.delivered,
      'read' => MessageStatus.read,
      _ => null,
    };
    return status == null ? null : Receipt(messageId: key, status: status);
  }

  final String messageId;
  final MessageStatus status;

  @override
  List<Object?> get props => [messageId, status];
}

/// Local drift DB is the source of truth. RTDB is only a relay:
/// - send:    local(pending) → inbox/{peer}/{id} → local(sent)
/// - receive: inbox/{me} → local(delivered) → receipts/{sender} → delete inbox node
/// - receipt: receipts/{me} → local status ↑ → delete receipt node
class ChatRepository {
  ChatRepository({required this._local, required this._me, FirebaseDatabase? database, Uuid? uuid})
    : _db = database ?? FirebaseDatabase.instance,
      _uuid = uuid ?? const Uuid();

  final AppDatabase _local;
  final AppUser _me;
  final FirebaseDatabase _db;
  final Uuid _uuid;

  // ---------------------------------------------------------------- reads

  Stream<List<ChatMessage>> watchMessages(String peerId) => _local.watchConversation(peerId);

  Stream<Map<String, ConversationSummary>> watchSummaries() => _local.watchSummaries();

  // ---------------------------------------------------------------- send

  Future<void> sendText(Contact peer, String text) async {
    final body = text.trim();
    if (body.isEmpty) return;
    final id = _uuid.v4();
    await _local.insertIfAbsent(
      ChatMessagesCompanion.insert(
        id: id,
        peerId: peer.uid,
        senderId: _me.uid,
        body: body,
        sentAt: DateTime.now().millisecondsSinceEpoch,
        status: MessageStatus.pending,
        isMine: true,
      ),
    );
    await _push(id: id, peer: peer, body: body);
  }

  Future<void> retry(String messageId, Contact peer) async {
    final msg = await _local.messageById(messageId);
    if (msg == null || !msg.isMine || msg.status != MessageStatus.failed) return;
    await _local.setStatus(messageId, MessageStatus.pending);
    await _push(id: messageId, peer: peer, body: msg.body);
  }

  Future<void> _push({required String id, required Contact peer, required String body}) async {
    final now = ServerValue.timestamp;
    try {
      // One atomic multi-path write: the message plus both contact-list entries.
      await _db.ref().update({
        '${RtdbPaths.inbox(peer.uid)}/$id': {
          'id': id,
          'chatId': chatIdFor(_me.uid, peer.uid),
          'senderId': _me.uid,
          'text': body,
          'sentAt': now,
        },
        '${RtdbPaths.userChats(_me.uid)}/${peer.uid}': {
          'peerName': peer.name,
          'peerEmail': peer.email,
          'updatedAt': now,
        },
        '${RtdbPaths.userChats(peer.uid)}/${_me.uid}': {
          'peerName': _me.name,
          'peerEmail': _me.email,
          'updatedAt': now,
        },
      });
      await _local.upgradeStatus(id, MessageStatus.sent);
    } catch (_) {
      await _local.setStatus(id, MessageStatus.failed);
      rethrow;
    }
  }

  /// Local-only "system" line in the conversation (e.g. "Missed video call").
  /// Each side writes its own; nothing goes through RTDB.
  Future<void> addCallLog({
    required String callId,
    required String peerId,
    required String text,
    required bool outgoing,
  }) => _local.insertIfAbsent(
    ChatMessagesCompanion.insert(
      id: 'call_$callId',
      peerId: peerId,
      senderId: outgoing ? _me.uid : peerId,
      body: text,
      sentAt: DateTime.now().millisecondsSinceEpoch,
      status: MessageStatus.read,
      kind: const Value(MessageKind.call),
      isMine: outgoing,
    ),
  );

  // ---------------------------------------------------------------- receive

  /// Every message currently in, and later added to, my inbox.
  Stream<IncomingMessage> incomingMessages() => _db
      .ref(RtdbPaths.inbox(_me.uid))
      .onChildAdded
      .map((e) => IncomingMessage.tryParse(e.snapshot.key, e.snapshot.value))
      .where((m) => m != null)
      .cast<IncomingMessage>();

  /// Saves locally first, then acknowledges, then deletes from RTDB.
  /// Safe to repeat: the local insert is idempotent.
  Future<void> ingest(IncomingMessage message) async {
    await _local.insertIfAbsent(
      ChatMessagesCompanion.insert(
        id: message.id,
        peerId: message.senderId,
        senderId: message.senderId,
        body: message.text,
        sentAt: message.sentAt,
        status: MessageStatus.delivered,
        isMine: false,
      ),
    );
    final local = await _local.messageById(message.id);
    await _db.ref().update({
      // Don't downgrade a "read" receipt if this is a re-delivery.
      if (local?.status != MessageStatus.read)
        '${RtdbPaths.receipts(message.senderId)}/${message.id}': _receipt('delivered'),
      '${RtdbPaths.inbox(_me.uid)}/${message.id}': null,
    });
  }

  // ---------------------------------------------------------------- receipts

  Stream<Receipt> receipts() {
    final ref = _db.ref(RtdbPaths.receipts(_me.uid));
    return mergeStreams([ref.onChildAdded, ref.onChildChanged])
        .map((e) => Receipt.tryParse(e.snapshot.key, e.snapshot.value))
        .where((r) => r != null)
        .cast<Receipt>();
  }

  Future<void> applyReceipt(Receipt receipt) async {
    await _local.upgradeStatus(receipt.messageId, receipt.status);
    // Delete only if the node still holds what we just applied. The peer often
    // writes "delivered" then "read" back to back; a blind remove() would shadow
    // the incoming "read" locally and we'd never see it.
    await _db.ref('${RtdbPaths.receipts(_me.uid)}/${receipt.messageId}').runTransaction((current) {
      final now = Receipt.tryParse(receipt.messageId, current);
      if (now != null && now.status != receipt.status) return Transaction.abort();
      return Transaction.success(null);
    }, applyLocally: false);
  }

  /// Marks everything [peerId] sent me as read, locally and for the sender.
  Future<void> markConversationRead(String peerId) async {
    final unread = await _local.unreadIncoming(peerId);
    if (unread.isEmpty) return;
    final ids = unread.map((m) => m.id).toList();
    await _local.markRead(ids);
    await _db.ref().update({
      for (final id in ids) '${RtdbPaths.receipts(peerId)}/$id': _receipt('read'),
    });
  }

  Map<String, Object> _receipt(String status) => {
    'status': status,
    'by': _me.uid,
    'at': ServerValue.timestamp,
  };
}
