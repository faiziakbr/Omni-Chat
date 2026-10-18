import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  const AppUser({required this.uid, required this.name, required this.email});

  factory AppUser.fromMap(String uid, Map<dynamic, dynamic> map) =>
      AppUser(uid: uid, name: map['name'] as String? ?? '', email: map['email'] as String? ?? '');

  final String uid;
  final String name;
  final String email;

  Map<String, dynamic> toMap() => {'name': name, 'email': email};

  @override
  List<Object?> get props => [uid, name, email];
}
