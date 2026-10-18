// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ChatMessagesTable extends ChatMessages with TableInfo<$ChatMessagesTable, ChatMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderIdMeta = const VerificationMeta('senderId');
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
    'sender_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<int> sentAt = GeneratedColumn<int>(
    'sent_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MessageStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<MessageStatus>($ChatMessagesTable.$converterstatus);
  @override
  late final GeneratedColumnWithTypeConverter<MessageKind, String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('text'),
  ).withConverter<MessageKind>($ChatMessagesTable.$converterkind);
  static const VerificationMeta _isMineMeta = const VerificationMeta('isMine');
  @override
  late final GeneratedColumn<bool> isMine = GeneratedColumn<bool>(
    'is_mine',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("is_mine" IN (0, 1))'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, peerId, senderId, body, sentAt, status, kind, isMine];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('peer_id')) {
      context.handle(_peerIdMeta, peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta));
    } else if (isInserting) {
      context.missing(_peerIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(
        _senderIdMeta,
        senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('body')) {
      context.handle(_bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('sent_at')) {
      context.handle(_sentAtMeta, sentAt.isAcceptableOrUnknown(data['sent_at']!, _sentAtMeta));
    } else if (isInserting) {
      context.missing(_sentAtMeta);
    }
    if (data.containsKey('is_mine')) {
      context.handle(_isMineMeta, isMine.isAcceptableOrUnknown(data['is_mine']!, _isMineMeta));
    } else if (isInserting) {
      context.missing(_isMineMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatMessage(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      )!,
      senderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_id'],
      )!,
      body: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      sentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sent_at'],
      )!,
      status: $ChatMessagesTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      ),
      kind: $ChatMessagesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      ),
      isMine: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_mine'],
      )!,
    );
  }

  @override
  $ChatMessagesTable createAlias(String alias) {
    return $ChatMessagesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MessageStatus, String, String> $converterstatus =
      const EnumNameConverter<MessageStatus>(MessageStatus.values);
  static JsonTypeConverter2<MessageKind, String, String> $converterkind =
      const EnumNameConverter<MessageKind>(MessageKind.values);
}

class ChatMessage extends DataClass implements Insertable<ChatMessage> {
  final String id;

  /// The other person in the 1v1 conversation.
  final String peerId;
  final String senderId;
  final String body;

  /// Milliseconds since epoch. Server time for incoming, local time for outgoing.
  final int sentAt;
  final MessageStatus status;
  final MessageKind kind;
  final bool isMine;
  const ChatMessage({
    required this.id,
    required this.peerId,
    required this.senderId,
    required this.body,
    required this.sentAt,
    required this.status,
    required this.kind,
    required this.isMine,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['peer_id'] = Variable<String>(peerId);
    map['sender_id'] = Variable<String>(senderId);
    map['body'] = Variable<String>(body);
    map['sent_at'] = Variable<int>(sentAt);
    {
      map['status'] = Variable<String>($ChatMessagesTable.$converterstatus.toSql(status));
    }
    {
      map['kind'] = Variable<String>($ChatMessagesTable.$converterkind.toSql(kind));
    }
    map['is_mine'] = Variable<bool>(isMine);
    return map;
  }

  ChatMessagesCompanion toCompanion(bool nullToAbsent) {
    return ChatMessagesCompanion(
      id: Value(id),
      peerId: Value(peerId),
      senderId: Value(senderId),
      body: Value(body),
      sentAt: Value(sentAt),
      status: Value(status),
      kind: Value(kind),
      isMine: Value(isMine),
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatMessage(
      id: serializer.fromJson<String>(json['id']),
      peerId: serializer.fromJson<String>(json['peerId']),
      senderId: serializer.fromJson<String>(json['senderId']),
      body: serializer.fromJson<String>(json['body']),
      sentAt: serializer.fromJson<int>(json['sentAt']),
      status: $ChatMessagesTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      kind: $ChatMessagesTable.$converterkind.fromJson(serializer.fromJson<String>(json['kind'])),
      isMine: serializer.fromJson<bool>(json['isMine']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'peerId': serializer.toJson<String>(peerId),
      'senderId': serializer.toJson<String>(senderId),
      'body': serializer.toJson<String>(body),
      'sentAt': serializer.toJson<int>(sentAt),
      'status': serializer.toJson<String>($ChatMessagesTable.$converterstatus.toJson(status)),
      'kind': serializer.toJson<String>($ChatMessagesTable.$converterkind.toJson(kind)),
      'isMine': serializer.toJson<bool>(isMine),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? peerId,
    String? senderId,
    String? body,
    int? sentAt,
    MessageStatus? status,
    MessageKind? kind,
    bool? isMine,
  }) => ChatMessage(
    id: id ?? this.id,
    peerId: peerId ?? this.peerId,
    senderId: senderId ?? this.senderId,
    body: body ?? this.body,
    sentAt: sentAt ?? this.sentAt,
    status: status ?? this.status,
    kind: kind ?? this.kind,
    isMine: isMine ?? this.isMine,
  );
  ChatMessage copyWithCompanion(ChatMessagesCompanion data) {
    return ChatMessage(
      id: data.id.present ? data.id.value : this.id,
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      body: data.body.present ? data.body.value : this.body,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
      status: data.status.present ? data.status.value : this.status,
      kind: data.kind.present ? data.kind.value : this.kind,
      isMine: data.isMine.present ? data.isMine.value : this.isMine,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessage(')
          ..write('id: $id, ')
          ..write('peerId: $peerId, ')
          ..write('senderId: $senderId, ')
          ..write('body: $body, ')
          ..write('sentAt: $sentAt, ')
          ..write('status: $status, ')
          ..write('kind: $kind, ')
          ..write('isMine: $isMine')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, peerId, senderId, body, sentAt, status, kind, isMine);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessage &&
          other.id == this.id &&
          other.peerId == this.peerId &&
          other.senderId == this.senderId &&
          other.body == this.body &&
          other.sentAt == this.sentAt &&
          other.status == this.status &&
          other.kind == this.kind &&
          other.isMine == this.isMine);
}

class ChatMessagesCompanion extends UpdateCompanion<ChatMessage> {
  final Value<String> id;
  final Value<String> peerId;
  final Value<String> senderId;
  final Value<String> body;
  final Value<int> sentAt;
  final Value<MessageStatus> status;
  final Value<MessageKind> kind;
  final Value<bool> isMine;
  final Value<int> rowid;
  const ChatMessagesCompanion({
    this.id = const Value.absent(),
    this.peerId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.body = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.status = const Value.absent(),
    this.kind = const Value.absent(),
    this.isMine = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatMessagesCompanion.insert({
    required String id,
    required String peerId,
    required String senderId,
    required String body,
    required int sentAt,
    required MessageStatus status,
    this.kind = const Value.absent(),
    required bool isMine,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       peerId = Value(peerId),
       senderId = Value(senderId),
       body = Value(body),
       sentAt = Value(sentAt),
       status = Value(status),
       isMine = Value(isMine);
  static Insertable<ChatMessage> custom({
    Expression<String>? id,
    Expression<String>? peerId,
    Expression<String>? senderId,
    Expression<String>? body,
    Expression<int>? sentAt,
    Expression<String>? status,
    Expression<String>? kind,
    Expression<bool>? isMine,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (peerId != null) 'peer_id': peerId,
      if (senderId != null) 'sender_id': senderId,
      if (body != null) 'body': body,
      if (sentAt != null) 'sent_at': sentAt,
      if (status != null) 'status': status,
      if (kind != null) 'kind': kind,
      if (isMine != null) 'is_mine': isMine,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? peerId,
    Value<String>? senderId,
    Value<String>? body,
    Value<int>? sentAt,
    Value<MessageStatus>? status,
    Value<MessageKind>? kind,
    Value<bool>? isMine,
    Value<int>? rowid,
  }) {
    return ChatMessagesCompanion(
      id: id ?? this.id,
      peerId: peerId ?? this.peerId,
      senderId: senderId ?? this.senderId,
      body: body ?? this.body,
      sentAt: sentAt ?? this.sentAt,
      status: status ?? this.status,
      kind: kind ?? this.kind,
      isMine: isMine ?? this.isMine,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<int>(sentAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>($ChatMessagesTable.$converterstatus.toSql(status.value));
    }
    if (kind.present) {
      map['kind'] = Variable<String>($ChatMessagesTable.$converterkind.toSql(kind.value));
    }
    if (isMine.present) {
      map['is_mine'] = Variable<bool>(isMine.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessagesCompanion(')
          ..write('id: $id, ')
          ..write('peerId: $peerId, ')
          ..write('senderId: $senderId, ')
          ..write('body: $body, ')
          ..write('sentAt: $sentAt, ')
          ..write('status: $status, ')
          ..write('kind: $kind, ')
          ..write('isMine: $isMine, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ChatMessagesTable chatMessages = $ChatMessagesTable(this);
  late final Index idxMessagesPeerTime = Index(
    'idx_messages_peer_time',
    'CREATE INDEX idx_messages_peer_time ON chat_messages (peer_id, sent_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [chatMessages, idxMessagesPeerTime];
}

typedef $$ChatMessagesTableCreateCompanionBuilder = ChatMessagesCompanion Function({
  required String id,
  required String peerId,
  required String senderId,
  required String body,
  required int sentAt,
  required MessageStatus status,
  Value<MessageKind> kind,
  required bool isMine,
  Value<int> rowid,
});
typedef $$ChatMessagesTableUpdateCompanionBuilder = ChatMessagesCompanion Function({
  Value<String> id,
  Value<String> peerId,
  Value<String> senderId,
  Value<String> body,
  Value<int> sentAt,
  Value<MessageStatus> status,
  Value<MessageKind> kind,
  Value<bool> isMine,
  Value<int> rowid,
});

class $$ChatMessagesTableFilterComposer extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get peerId =>
      $composableBuilder(column: $table.peerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<MessageStatus, MessageStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<MessageKind, MessageKind, String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get isMine =>
      $composableBuilder(column: $table.isMine, builder: (column) => ColumnFilters(column));
}

class $$ChatMessagesTableOrderingComposer extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get peerId =>
      $composableBuilder(column: $table.peerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isMine =>
      $composableBuilder(column: $table.isMine, builder: (column) => ColumnOrderings(column));
}

class $$ChatMessagesTableAnnotationComposer extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get peerId =>
      $composableBuilder(column: $table.peerId, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MessageStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MessageKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<bool> get isMine =>
      $composableBuilder(column: $table.isMine, builder: (column) => column);
}

class $$ChatMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatMessagesTable,
          ChatMessage,
          $$ChatMessagesTableFilterComposer,
          $$ChatMessagesTableOrderingComposer,
          $$ChatMessagesTableAnnotationComposer,
          $$ChatMessagesTableCreateCompanionBuilder,
          $$ChatMessagesTableUpdateCompanionBuilder,
          (ChatMessage, BaseReferences<_$AppDatabase, $ChatMessagesTable, ChatMessage>),
          ChatMessage,
          PrefetchHooks Function()
        > {
  $$ChatMessagesTableTableManager(_$AppDatabase db, $ChatMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ChatMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ChatMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> peerId = const Value.absent(),
                Value<String> senderId = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> sentAt = const Value.absent(),
                Value<MessageStatus> status = const Value.absent(),
                Value<MessageKind> kind = const Value.absent(),
                Value<bool> isMine = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatMessagesCompanion(
                id: id,
                peerId: peerId,
                senderId: senderId,
                body: body,
                sentAt: sentAt,
                status: status,
                kind: kind,
                isMine: isMine,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String peerId,
                required String senderId,
                required String body,
                required int sentAt,
                required MessageStatus status,
                Value<MessageKind> kind = const Value.absent(),
                required bool isMine,
                Value<int> rowid = const Value.absent(),
              }) => ChatMessagesCompanion.insert(
                id: id,
                peerId: peerId,
                senderId: senderId,
                body: body,
                sentAt: sentAt,
                status: status,
                kind: kind,
                isMine: isMine,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChatMessagesTable, ChatMessage>(table),
                  BaseReferences<_$AppDatabase, $ChatMessagesTable, ChatMessage>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatMessagesTable,
      ChatMessage,
      $$ChatMessagesTableFilterComposer,
      $$ChatMessagesTableOrderingComposer,
      $$ChatMessagesTableAnnotationComposer,
      $$ChatMessagesTableCreateCompanionBuilder,
      $$ChatMessagesTableUpdateCompanionBuilder,
      (ChatMessage, BaseReferences<_$AppDatabase, $ChatMessagesTable, ChatMessage>),
      ChatMessage,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ChatMessagesTableTableManager get chatMessages =>
      $$ChatMessagesTableTableManager(_db, _db.chatMessages);
}
