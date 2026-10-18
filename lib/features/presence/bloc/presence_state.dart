part of 'presence_bloc.dart';

final class PresenceState extends Equatable {
  const PresenceState({this.online = false});
  final bool online;
  @override
  List<Object?> get props => [online];
}
