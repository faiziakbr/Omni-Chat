import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/email_key.dart';
import '../../auth/data/app_user.dart';
import '../data/user_repository.dart';

part 'user_search_event.dart';
part 'user_search_state.dart';

class UserSearchBloc extends Bloc<UserSearchEvent, UserSearchState> {
  UserSearchBloc({required this._userRepository, required this._me})
    : super(const UserSearchState()) {
    on<UserSearchSubmitted>(_onSubmitted, transformer: restartable());
    on<UserSearchStartChatPressed>(_onStartChat, transformer: droppable());
  }

  final UserRepository _userRepository;
  final AppUser _me;

  Future<void> _onSubmitted(UserSearchSubmitted event, Emitter<UserSearchState> emit) async {
    if (emailKey(event.email) == emailKey(_me.email)) {
      emit(
        const UserSearchState(status: UserSearchStatus.failure, error: "That's your own email."),
      );
      return;
    }
    emit(const UserSearchState(status: UserSearchStatus.searching));
    try {
      final user = await _userRepository.findByEmail(event.email);
      emit(
        user == null
            ? const UserSearchState(status: UserSearchStatus.notFound)
            : UserSearchState(status: UserSearchStatus.found, result: user),
      );
    } on UserLookupFailure catch (e) {
      emit(UserSearchState(status: UserSearchStatus.failure, error: e.message));
    } catch (_) {
      emit(
        const UserSearchState(
          status: UserSearchStatus.failure,
          error: "Couldn't search. Check your connection.",
        ),
      );
    }
  }

  Future<void> _onStartChat(UserSearchStartChatPressed event, Emitter<UserSearchState> emit) async {
    final peer = state.result;
    if (peer == null) return;
    emit(state.copyWith(status: UserSearchStatus.linking));
    try {
      await _userRepository.linkContacts(me: _me, peer: peer);
      emit(state.copyWith(status: UserSearchStatus.linked));
    } catch (_) {
      emit(
        state.copyWith(
          status: UserSearchStatus.failure,
          error: "Couldn't start the chat. Try again.",
        ),
      );
    }
  }
}
