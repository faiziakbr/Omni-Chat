import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../chat/data/chat_repository.dart';
import '../../chat/data/local/app_database.dart';
import '../../presence/data/presence.dart';
import '../../presence/data/presence_repository.dart';
import '../data/contact.dart';
import '../data/user_repository.dart';

part 'contacts_event.dart';
part 'contacts_state.dart';

class ContactsBloc extends Bloc<ContactsEvent, ContactsState> {
  ContactsBloc({
    required this._userRepository,
    required this._presenceRepository,
    required this._chatRepository,
    required this._uid,
  }) : super(const ContactsState()) {
    on<ContactsSubscriptionRequested>(_onSubscriptionRequested, transformer: restartable());
    on<_ContactPresenceChanged>(_onPresenceChanged);
  }

  final UserRepository _userRepository;
  final PresenceRepository _presenceRepository;
  final ChatRepository _chatRepository;
  final String _uid;

  /// One presence subscription per contact; these outlive a single handler.
  final Map<String, StreamSubscription<Presence>> _presenceSubs = {};

  Future<void> _onSubscriptionRequested(
    ContactsSubscriptionRequested event,
    Emitter<ContactsState> emit,
  ) async {
    emit(state.copyWith(status: ContactsStatus.loading));
    await Future.wait([
      emit.forEach<List<Contact>>(
        _userRepository.contacts(_uid),
        onData: (contacts) {
          _syncPresenceSubs(contacts);
          return state.copyWith(status: ContactsStatus.success, contacts: contacts);
        },
        onError: (_, _) => state.copyWith(status: ContactsStatus.failure),
      ),
      emit.forEach<Map<String, ConversationSummary>>(
        _chatRepository.watchSummaries(),
        onData: (summaries) => state.copyWith(summaries: summaries),
        onError: (_, _) => state,
      ),
    ]);
  }

  void _onPresenceChanged(_ContactPresenceChanged event, Emitter<ContactsState> emit) {
    emit(state.copyWith(presence: {...state.presence, event.uid: event.presence}));
  }

  void _syncPresenceSubs(List<Contact> contacts) {
    final wanted = contacts.map((c) => c.uid).toSet();
    for (final uid in _presenceSubs.keys.toList()) {
      if (!wanted.contains(uid)) _presenceSubs.remove(uid)?.cancel();
    }
    for (final uid in wanted) {
      _presenceSubs.putIfAbsent(
        uid,
        () => _presenceRepository
            .watch(uid)
            .listen((p) => add(_ContactPresenceChanged(uid, p)), onError: (_) {}),
      );
    }
  }

  @override
  Future<void> close() async {
    for (final sub in _presenceSubs.values) {
      await sub.cancel();
    }
    return super.close();
  }
}
