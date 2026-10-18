import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/connectivity/data/connectivity_repository.dart';
import 'features/contacts/data/user_repository.dart';
import 'features/presence/data/presence_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    App(
      authRepository: AuthRepository(),
      userRepository: UserRepository(),
      presenceRepository: PresenceRepository(),
      connectivityRepository: ConnectivityRepository(),
    ),
  );
}
