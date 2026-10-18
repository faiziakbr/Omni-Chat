part of 'presence_bloc.dart';

sealed class PresenceEvent extends Equatable {
  const PresenceEvent();
  @override
  List<Object?> get props => [];
}

final class PresenceStarted extends PresenceEvent {
  const PresenceStarted();
}

final class PresenceStopped extends PresenceEvent {
  const PresenceStopped();
}
