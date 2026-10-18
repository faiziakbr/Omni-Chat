part of 'user_search_bloc.dart';

enum UserSearchStatus { initial, searching, found, notFound, failure, linking, linked }

final class UserSearchState extends Equatable {
  const UserSearchState({this.status = UserSearchStatus.initial, this.result, this.error});

  final UserSearchStatus status;
  final AppUser? result;
  final String? error;

  UserSearchState copyWith({UserSearchStatus? status, AppUser? result, String? error}) =>
      UserSearchState(status: status ?? this.status, result: result ?? this.result, error: error);

  @override
  List<Object?> get props => [status, result, error];
}
