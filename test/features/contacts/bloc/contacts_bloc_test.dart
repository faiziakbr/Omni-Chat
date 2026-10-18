import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omni_chat/features/chat/data/chat_repository.dart';
import 'package:omni_chat/features/chat/data/local/app_database.dart';
import 'package:omni_chat/features/contacts/bloc/contacts_bloc.dart';
import 'package:omni_chat/features/contacts/data/contact.dart';
import 'package:omni_chat/features/contacts/data/user_repository.dart';
import 'package:omni_chat/features/presence/data/presence.dart';
import 'package:omni_chat/features/presence/data/presence_repository.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockPresenceRepository extends Mock implements PresenceRepository {}

class _MockChatRepository extends Mock implements ChatRepository {}

void main() {
  final old = Contact(uid: 'a', name: 'A', email: 'a@x', updatedAt: DateTime(2026));
  final recent = Contact(uid: 'b', name: 'B', email: 'b@x', updatedAt: DateTime(2026, 2));
  late _MockUserRepository users;
  late _MockPresenceRepository presence;
  late _MockChatRepository chat;

  setUp(() {
    users = _MockUserRepository();
    presence = _MockPresenceRepository();
    chat = _MockChatRepository();
    when(() => presence.watch(any())).thenAnswer((_) => const Stream.empty());
    when(() => chat.watchSummaries()).thenAnswer((_) => const Stream.empty());
  });

  ContactsBloc build() => ContactsBloc(
    userRepository: users,
    presenceRepository: presence,
    chatRepository: chat,
    uid: 'me',
  );

  blocTest<ContactsBloc, ContactsState>(
    'loads contacts and subscribes to each contact presence',
    setUp: () => when(() => users.contacts('me')).thenAnswer((_) => Stream.value([recent, old])),
    build: build,
    act: (b) => b.add(const ContactsSubscriptionRequested()),
    expect: () => [
      const ContactsState(status: ContactsStatus.loading),
      ContactsState(status: ContactsStatus.success, contacts: [recent, old]),
    ],
    verify: (_) {
      verify(() => presence.watch('a')).called(1);
      verify(() => presence.watch('b')).called(1);
    },
  );

  blocTest<ContactsBloc, ContactsState>(
    'presence updates land in state',
    setUp: () {
      when(() => users.contacts('me')).thenAnswer((_) => Stream.value([old]));
      when(() => presence.watch('a')).thenAnswer((_) => Stream.value(const Presence(online: true)));
    },
    build: build,
    act: (b) => b.add(const ContactsSubscriptionRequested()),
    skip: 2,
    expect: () => [
      ContactsState(
        status: ContactsStatus.success,
        contacts: [old],
        presence: const {'a': Presence(online: true)},
      ),
    ],
  );

  test('sortedContacts puts the most recent local message first', () {
    final msg = ChatMessage(
      id: 'm',
      peerId: 'a',
      senderId: 'a',
      body: 'hi',
      sentAt: DateTime(2026, 3).millisecondsSinceEpoch,
      status: MessageStatus.delivered,
      kind: MessageKind.text,
      isMine: false,
    );
    final state = ContactsState(
      contacts: [recent, old],
      summaries: {'a': ConversationSummary(last: msg, unread: 1)},
    );
    expect(state.sortedContacts.map((c) => c.uid), ['a', 'b']);
  });

  test('failure status when the contacts stream errors', () async {
    when(() => users.contacts('me')).thenAnswer((_) => Stream.error(Exception('denied')));
    final bloc = build()..add(const ContactsSubscriptionRequested());
    await expectLater(bloc.stream.map((s) => s.status), emitsThrough(ContactsStatus.failure));
    await bloc.close();
  });
}
