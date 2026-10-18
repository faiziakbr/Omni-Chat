import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/stream_listenable.dart';
import '../core/widgets/brand_mark.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/view/login_page.dart';
import '../features/auth/view/register_page.dart';
import '../features/chat/view/chat_page.dart';
import '../features/contacts/data/contact.dart';
import '../features/contacts/view/home_page.dart';
import '../features/contacts/view/search_page.dart';
import 'session_scope.dart';

GoRouter buildRouter(AuthBloc authBloc) {
  const publicRoutes = {'/login', '/register'};

  return GoRouter(
    initialLocation: '/',
    refreshListenable: StreamListenable(authBloc.stream),
    redirect: (context, state) {
      final status = authBloc.state.status;
      final loc = state.matchedLocation;
      if (status == AuthStatus.unknown) return loc == '/splash' ? null : '/splash';
      final loggedIn = status == AuthStatus.authenticated;
      if (!loggedIn) return publicRoutes.contains(loc) ? null : '/login';
      if (publicRoutes.contains(loc) || loc == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) => const Scaffold(body: Center(child: BrandMark(size: 88))),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      ShellRoute(
        builder: (context, state, child) {
          final user = authBloc.state.user!;
          // Keyed by uid so switching accounts rebuilds every user-scoped resource.
          return SessionScope(key: ValueKey(user.uid), user: user, child: child);
        },
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HomePage()),
          GoRoute(path: '/search', builder: (_, _) => const SearchPage()),
          GoRoute(
            path: '/chat/:peerId',
            builder: (_, state) => ChatPage(
              peerId: state.pathParameters['peerId']!,
              peer: state.extra is Contact ? state.extra! as Contact : null,
            ),
          ),
        ],
      ),
    ],
  );
}
