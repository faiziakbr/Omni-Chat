part of 'user_search_bloc.dart';

sealed class UserSearchEvent extends Equatable {
  const UserSearchEvent();
  @override
  List<Object?> get props => [];
}

final class UserSearchSubmitted extends UserSearchEvent {
  const UserSearchSubmitted(this.email);
  final String email;
  @override
  List<Object?> get props => [email];
}

final class UserSearchStartChatPressed extends UserSearchEvent {
  const UserSearchStartChatPressed();
}
