import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omni_chat/features/connectivity/bloc/connectivity_bloc.dart';
import 'package:omni_chat/features/connectivity/data/connectivity_repository.dart';

class _MockConnectivityRepository extends Mock implements ConnectivityRepository {}

const _grace = Duration(milliseconds: 20);
const _online = ConnectivityState(status: ConnectivityStatus.online);
const _offline = ConnectivityState(status: ConnectivityStatus.offline);

void main() {
  late _MockConnectivityRepository repo;
  late StreamController<bool> connected;

  setUp(() {
    repo = _MockConnectivityRepository();
    connected = StreamController<bool>();
    when(() => repo.watchConnected()).thenAnswer((_) => connected.stream);
  });
  // Not awaited: close() never completes on a stream nobody listened to.
  tearDown(() => unawaited(connected.close()));

  ConnectivityBloc build() => ConnectivityBloc(connectivityRepository: repo, gracePeriod: _grace);

  test('starts unknown', () {
    expect(build().state, const ConnectivityState());
  });

  blocTest<ConnectivityBloc, ConnectivityState>(
    'goes online as soon as the socket connects',
    build: build,
    act: (b) {
      b.add(const ConnectivitySubscriptionRequested());
      connected.add(true);
    },
    expect: () => const [_online],
  );

  blocTest<ConnectivityBloc, ConnectivityState>(
    'startup handshake (false, then true within the grace period) never shows offline',
    build: build,
    act: (b) async {
      b.add(const ConnectivitySubscriptionRequested());
      connected.add(false);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      connected.add(true);
    },
    wait: _grace * 3,
    expect: () => const [_online],
  );

  blocTest<ConnectivityBloc, ConnectivityState>(
    'goes offline once a disconnect outlasts the grace period',
    build: build,
    act: (b) async {
      b.add(const ConnectivitySubscriptionRequested());
      connected.add(true);
      await Future<void>.delayed(Duration.zero);
      connected.add(false);
    },
    wait: _grace * 3,
    expect: () => const [_online, _offline],
  );

  blocTest<ConnectivityBloc, ConnectivityState>(
    'comes back online after reconnecting',
    build: build,
    seed: () => _offline,
    act: (b) {
      b.add(const ConnectivitySubscriptionRequested());
      connected.add(true);
    },
    expect: () => const [_online],
  );

  blocTest<ConnectivityBloc, ConnectivityState>(
    'stream errors are ignored',
    build: build,
    act: (b) {
      b.add(const ConnectivitySubscriptionRequested());
      connected.addError(Exception('boom'));
    },
    expect: () => const <ConnectivityState>[],
  );
}
