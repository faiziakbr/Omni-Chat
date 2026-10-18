import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omni_chat/features/auth/data/app_user.dart';
import 'package:omni_chat/features/chat/bloc/chat_bloc.dart';
import 'package:omni_chat/features/chat/data/chat_repository.dart';
import 'package:omni_chat/features/chat/data/local/app_database.dart';
import 'package:omni_chat/features/contacts/data/contact.dart';
import 'package:omni_chat/features/contacts/data/user_repository.dart';
import 'package:omni_chat/features/presence/data/presence.dart';
import 'package:omni_chat/features/presence/data/presence_repository.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

class _MockPresenceRepository extends Mock implements PresenceRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

ChatMessage _msg(String id, {bool mine = false, MessageStatus status = MessageStatus.delivered}) =>
    ChatMessage(
      id: id,
      peerId: 'bob',
      senderId: mine ? 'me' : 'bob',
      body: 'text $id',
      sentAt: 1,
      status: status,
      kind: MessageKind.text,
      isMine: mine,
    );

void main() {
  final bob = Contact(uid: 'bob', name: 'Bob', email: 'bob@x', updatedAt: DateTime(2026));
  late _MockChatRepository chat;
  late _MockPresenceRepository presence;
  late _MockUserRepository users;

  setUpAll(() => registerFallbackValue(bob));

  setUp(() {
    chat = _MockChatRepository();
    presence = _MockPresenceRepository();
    users = _MockUserRepository();
    when(() => presence.watch('bob')).thenAnswer((_) => const Stream.empty());
    when(() => chat.watchMessages('bob')).thenAnswer((_) => const Stream.empty());
    when(() => chat.markConversationRead('bob')).thenAnswer((_) async {});
    when(() => chat.sendText(any(), any())).thenAnswer((_) async {});
  });

  ChatBloc build({Contact? peer}) => ChatBloc(
    chatRepository: chat,
    presenceRepository: presence,
    userRepository: users,
    peerId: 'bob',
    peer: peer,
  );

  blocTest<ChatBloc, ChatState>(
    'streams local messages and marks unread incoming as read',
    setUp: () {
      when(() => chat.watchMessages('bob')).thenAnswer((_) => Stream.value([_msg('1')]));
    },
    build: () => build(peer: bob),
    act: (b) => b.add(const ChatSubscriptionRequested()),
    expect: () => [
      ChatState(peerId: 'bob', peer: bob, status: ChatStatus.ready, messages: [_msg('1')]),
    ],
    verify: (_) => verify(() => chat.markConversationRead('bob')).called(1),
  );

  blocTest<ChatBloc, ChatState>(
    'a message arriving while a mark-read is in flight still gets marked read',
    setUp: () {
      when(() => chat.watchMessages('bob')).thenAnswer(
        (_) => Stream.fromIterable([
          [_msg('1')],
          [_msg('1'), _msg('2')],
        ]),
      );
      when(() => chat.markConversationRead('bob'))
          .thenAnswer((_) => Future<void>.delayed(const Duration(milliseconds: 20)));
    },
    build: () => build(peer: bob),
    act: (b) => b.add(const ChatSubscriptionRequested()),
    wait: const Duration(milliseconds: 100),
    verify: (_) => verify(() => chat.markConversationRead('bob')).called(2),
  );

  blocTest<ChatBloc, ChatState>(
    'does not mark read when nothing is unread',
    setUp: () {
      when(() => chat.watchMessages('bob')).thenAnswer(
        (_) => Stream.value([_msg('1', status: MessageStatus.read), _msg('2', mine: true)]),
      );
    },
    build: () => build(peer: bob),
    act: (b) => b.add(const ChatSubscriptionRequested()),
    verify: (_) => verifyNever(() => chat.markConversationRead(any())),
  );

  blocTest<ChatBloc, ChatState>(
    'loads the peer by uid when opened without a contact',
    setUp: () =>
        when(() => users.getUser('bob'))
            .thenAnswer((_) async => const AppUser(uid: 'bob', name: 'Bob', email: 'bob@x')),
    build: build,
    act: (b) => b.add(const ChatSubscriptionRequested()),
    expect: () => [isA<ChatState>().having((s) => s.peer?.name, 'peer name', 'Bob')],
  );

  blocTest<ChatBloc, ChatState>(
    'fails when the peer does not exist',
    setUp: () => when(() => users.getUser('bob')).thenAnswer((_) async => null),
    build: build,
    act: (b) => b.add(const ChatSubscriptionRequested()),
    expect: () => [
      const ChatState(peerId: 'bob', status: ChatStatus.failure, error: 'User not found.'),
    ],
  );

  blocTest<ChatBloc, ChatState>(
    'peer presence lands in state',
    setUp: () =>
        when(() => presence.watch('bob'))
            .thenAnswer((_) => Stream.value(const Presence(online: true))),
    build: () => build(peer: bob),
    act: (b) => b.add(const ChatSubscriptionRequested()),
    expect: () => [ChatState(peerId: 'bob', peer: bob, peerPresence: const Presence(online: true))],
  );

  blocTest<ChatBloc, ChatState>(
    'send delegates to the repository and ignores blank text',
    build: () => build(peer: bob),
    act: (b) => b
      ..add(const ChatMessageSubmitted('   '))
      ..add(const ChatMessageSubmitted('hello')),
    verify: (_) {
      verify(() => chat.sendText(bob, 'hello')).called(1);
      verifyNoMoreInteractions(chat);
    },
  );

  blocTest<ChatBloc, ChatState>(
    'retry delegates to the repository',
    setUp: () => when(() => chat.retry('9', bob)).thenAnswer((_) async {}),
    build: () => build(peer: bob),
    act: (b) => b.add(const ChatRetryPressed('9')),
    verify: (_) => verify(() => chat.retry('9', bob)).called(1),
  );
}
