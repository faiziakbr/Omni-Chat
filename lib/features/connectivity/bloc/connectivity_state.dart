part of 'connectivity_bloc.dart';

enum ConnectivityStatus { unknown, online, offline }

final class ConnectivityState extends Equatable {
  const ConnectivityState({this.status = ConnectivityStatus.unknown});
  final ConnectivityStatus status;

  bool get isOffline => status == ConnectivityStatus.offline;

  @override
  List<Object?> get props => [status];
}
