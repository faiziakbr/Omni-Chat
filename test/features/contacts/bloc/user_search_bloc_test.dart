import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omni_chat/features/auth/data/app_user.dart';
import 'package:omni_chat/features/contacts/bloc/user_search_bloc.dart';
import 'package:omni_chat/features/contacts/data/user_repository.dart';

class _MockUserRepository extends Mock implements UserRepository {}

void main() {
  const me = AppUser(uid: 'me', name: 'Me', email: 'me@x.com');
  const bob = AppUser(uid: 'bob', name: 'Bob', email: 'bob@x.com');
  late _MockUserRepository repo;

  setUp(() => repo = _MockUserRepository());
  UserSearchBloc build() => UserSearchBloc(userRepository: repo, me: me);

  blocTest<UserSearchBloc, UserSearchState>(
    'found',
    setUp: () => when(() => repo.findByEmail('bob@x.com')).thenAnswer((_) async => bob),
    build: build,
    act: (b) => b.add(const UserSearchSubmitted('bob@x.com')),
    expect: () => const [
      UserSearchState(status: UserSearchStatus.searching),
      UserSearchState(status: UserSearchStatus.found, result: bob),
    ],
  );

  blocTest<UserSearchBloc, UserSearchState>(
    'not found',
    setUp: () => when(() => repo.findByEmail(any())).thenAnswer((_) async => null),
    build: build,
    act: (b) => b.add(const UserSearchSubmitted('nobody@x.com')),
    expect: () => const [
      UserSearchState(status: UserSearchStatus.searching),
      UserSearchState(status: UserSearchStatus.notFound),
    ],
  );

  blocTest<UserSearchBloc, UserSearchState>(
    'rejects my own email (case-insensitive) without hitting the repository',
    build: build,
    act: (b) => b.add(const UserSearchSubmitted(' ME@x.com ')),
    expect: () => const [
      UserSearchState(status: UserSearchStatus.failure, error: "That's your own email."),
    ],
    verify: (_) => verifyNever(() => repo.findByEmail(any())),
  );

  blocTest<UserSearchBloc, UserSearchState>(
    'start chat links both contacts',
    setUp: () => when(() => repo.linkContacts(me: me, peer: bob)).thenAnswer((_) async {}),
    build: build,
    seed: () => const UserSearchState(status: UserSearchStatus.found, result: bob),
    act: (b) => b.add(const UserSearchStartChatPressed()),
    expect: () => const [
      UserSearchState(status: UserSearchStatus.linking, result: bob),
      UserSearchState(status: UserSearchStatus.linked, result: bob),
    ],
  );
}
