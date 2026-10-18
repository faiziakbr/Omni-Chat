part of 'connectivity_bloc.dart';

sealed class ConnectivityEvent extends Equatable {
  const ConnectivityEvent();
  @override
  List<Object?> get props => [];
}

final class ConnectivitySubscriptionRequested extends ConnectivityEvent {
  const ConnectivitySubscriptionRequested();
}

final class _GracePeriodElapsed extends ConnectivityEvent {
  const _GracePeriodElapsed();
}
