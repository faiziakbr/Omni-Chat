import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/connectivity/bloc/connectivity_bloc.dart';
import '../features/connectivity/data/connectivity_repository.dart';
import '../features/connectivity/view/offline_banner.dart';
import '../features/contacts/data/user_repository.dart';
import '../features/presence/data/presence_repository.dart';
import 'router.dart';

class App extends StatelessWidget {
  const App({
    super.key,
    required this.authRepository,
    required this.userRepository,
    required this.presenceRepository,
    required this.connectivityRepository,
  });

  final AuthRepository authRepository;
  final UserRepository userRepository;
  final PresenceRepository presenceRepository;
  final ConnectivityRepository connectivityRepository;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: userRepository),
        RepositoryProvider.value(value: presenceRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                AuthBloc(authRepository: authRepository)..add(const AuthSubscriptionRequested()),
          ),
          BlocProvider(
            lazy: false,
            create: (_) =>
                ConnectivityBloc(connectivityRepository: connectivityRepository)
                  ..add(const ConnectivitySubscriptionRequested()),
          ),
        ],
        child: const _AppView(),
      ),
    );
  }
}

class _AppView extends StatefulWidget {
  const _AppView();

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  late final GoRouter _router = buildRouter(context.read<AuthBloc>());

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Omni Chat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: _router,
      builder: (_, child) => OfflineBanner(child: child ?? const SizedBox.shrink()),
    );
  }
}
