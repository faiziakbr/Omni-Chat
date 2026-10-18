import 'package:equatable/equatable.dart';

import '../../auth/data/app_user.dart';

/// An entry in `userChats/{me}`: someone I can chat with or call.
class Contact extends Equatable {
  const Contact({
    required this.uid,
    required this.name,
    required this.email,
    required this.updatedAt,
  });

  factory Contact.fromMap(String uid, Map<dynamic, dynamic> map) => Contact(
    uid: uid,
    name: map['peerName'] as String? ?? '',
    email: map['peerEmail'] as String? ?? '',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int? ?? 0),
  );

  factory Contact.fromUser(AppUser user) =>
      Contact(uid: user.uid, name: user.name, email: user.email, updatedAt: DateTime.now());

  final String uid;
  final String name;
  final String email;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [uid, name, email, updatedAt];
}
