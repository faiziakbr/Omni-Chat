import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/connectivity_repository.dart';

part 'connectivity_event.dart';
part 'connectivity_state.dart';

/// App-wide: tracks the RTDB connection for the offline banner. A disconnect
/// only counts once it outlasts [gracePeriod], so the startup handshake and
/// brief reconnects don't flash the banner.
class ConnectivityBloc extends Bloc<ConnectivityEvent, ConnectivityState> {
  ConnectivityBloc({
    required this._connectivityRepository,
    this.gracePeriod = const Duration(seconds: 3),
  }) : super(const ConnectivityState()) {
    on<ConnectivitySubscriptionRequested>(_onSubscriptionRequested, transformer: restartable());
    on<_GracePeriodElapsed>(_onGracePeriodElapsed);
  }

  final ConnectivityRepository _connectivityRepository;
  final Duration gracePeriod;
  Timer? _graceTimer;

  Future<void> _onSubscriptionRequested(
    ConnectivitySubscriptionRequested event,
    Emitter<ConnectivityState> emit,
  ) {
    return emit.onEach<bool>(
      _connectivityRepository.watchConnected(),
      onData: (connected) {
        _graceTimer?.cancel();
        if (connected) {
          emit(const ConnectivityState(status: ConnectivityStatus.online));
        } else {
          _graceTimer = Timer(gracePeriod, () => add(const _GracePeriodElapsed()));
        }
      },
      onError: (_, _) {},
    );
  }

  void _onGracePeriodElapsed(_GracePeriodElapsed event, Emitter<ConnectivityState> emit) {
    emit(const ConnectivityState(status: ConnectivityStatus.offline));
  }

  @override
  Future<void> close() {
    _graceTimer?.cancel();
    return super.close();
  }
}
