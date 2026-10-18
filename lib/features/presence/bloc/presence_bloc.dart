import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/presence_repository.dart';

part 'presence_event.dart';
part 'presence_state.dart';

/// Session-scoped: keeps my own presence node up to date while signed in.
class PresenceBloc extends Bloc<PresenceEvent, PresenceState> {
  PresenceBloc({required this._presenceRepository, required this._uid})
    : super(const PresenceState()) {
    on<PresenceStarted>(_onStarted, transformer: droppable());
    on<PresenceStopped>(_onStopped, transformer: droppable());
  }

  final PresenceRepository _presenceRepository;
  final String _uid;

  void _onStarted(PresenceStarted event, Emitter<PresenceState> emit) {
    _presenceRepository.goOnline(_uid);
    emit(const PresenceState(online: true));
  }

  Future<void> _onStopped(PresenceStopped event, Emitter<PresenceState> emit) async {
    try {
      await _presenceRepository.goOffline(_uid);
    } catch (_) {
      // Already signed out or offline; onDisconnect covers it.
    }
    emit(const PresenceState(online: false));
  }
}
