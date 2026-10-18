import 'package:equatable/equatable.dart';

class Presence extends Equatable {
  const Presence({required this.online, this.lastSeen});

  const Presence.offline() : this(online: false);

  factory Presence.fromMap(Map<dynamic, dynamic>? map) => Presence(
    online: map?['online'] as bool? ?? false,
    lastSeen: map?['lastSeen'] is int
        ? DateTime.fromMillisecondsSinceEpoch(map!['lastSeen'] as int)
        : null,
  );

  final bool online;
  final DateTime? lastSeen;

  @override
  List<Object?> get props => [online, lastSeen];
}
