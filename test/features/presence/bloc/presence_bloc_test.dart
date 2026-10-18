import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omni_chat/features/presence/bloc/presence_bloc.dart';
import 'package:omni_chat/features/presence/data/presence_repository.dart';

class _MockPresenceRepository extends Mock implements PresenceRepository {}

void main() {
  late _MockPresenceRepository repo;
  setUp(() => repo = _MockPresenceRepository());

  blocTest<PresenceBloc, PresenceState>(
    'start goes online',
    build: () => PresenceBloc(presenceRepository: repo, uid: 'me'),
    act: (b) => b.add(const PresenceStarted()),
    expect: () => const [PresenceState(online: true)],
    verify: (_) => verify(() => repo.goOnline('me')).called(1),
  );

  blocTest<PresenceBloc, PresenceState>(
    'stop goes offline, even if the write fails',
    setUp: () => when(() => repo.goOffline('me')).thenThrow(Exception('signed out')),
    build: () => PresenceBloc(presenceRepository: repo, uid: 'me'),
    seed: () => const PresenceState(online: true),
    act: (b) => b.add(const PresenceStopped()),
    expect: () => const [PresenceState(online: false)],
  );
}
