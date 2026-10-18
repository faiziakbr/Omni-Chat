import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/auth/data/app_user.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/call/bloc/call_bloc.dart';
import '../features/call/data/ringer/call_ringer.dart';
import '../features/call/data/signaling_repository.dart';
import '../features/call/data/webrtc_service.dart';
import '../features/call/view/call_screen.dart';
import '../features/chat/bloc/chat_sync_bloc.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/chat/data/local/app_database.dart';
import '../features/presence/bloc/presence_bloc.dart';
import '../features/presence/data/presence_repository.dart';

/// Wraps every signed-in route. Owns user-scoped resources (local DB, chat
/// repository) and session-wide blocs (presence, chat sync, calls).
class SessionScope extends StatefulWidget {
  const SessionScope({super.key, required this.user, required this.child});

  final AppUser user;
  final Widget child;

  @override
  State<SessionScope> createState() => _SessionScopeState();
}

class _SessionScopeState extends State<SessionScope> {
  late final AuthRepository _authRepository = context.read<AuthRepository>();
  late final PresenceRepository _presenceRepository = context.read<PresenceRepository>();
  late final AppDatabase _database = AppDatabase.forUser(widget.user.uid);
  late final ChatRepository _chatRepository = ChatRepository(local: _database, me: widget.user);

  /// Must run while still signed in, so it's a logout hook rather than dispose().
  /// (Method tear-offs compare equal, so remove works.)
  Future<void> _presenceHook() => _presenceRepository.goOffline(widget.user.uid);

  @override
  void initState() {
    super.initState();
    _authRepository.addLogoutHook(_presenceHook);
  }

  @override
  void dispose() {
    _authRepository.removeLogoutHook(_presenceHook);
    _database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AppUser>.value(value: widget.user),
        RepositoryProvider<ChatRepository>.value(value: _chatRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            lazy: false,
            create: (_) =>
                PresenceBloc(presenceRepository: _presenceRepository, uid: widget.user.uid)
                  ..add(const PresenceStarted()),
          ),
          BlocProvider(
            lazy: false,
            create: (_) =>
                ChatSyncBloc(chatRepository: _chatRepository)..add(const ChatSyncStarted()),
          ),
          BlocProvider(
            lazy: false,
            create: (_) => CallBloc(
              signaling: SignalingRepository(me: widget.user),
              webRtc: WebRtcService(),
              ringer: CallRinger(),
              chatRepository: _chatRepository,
            )..add(const CallSubscriptionRequested()),
          ),
        ],
        // The call UI floats above whatever route is showing.
        child: Stack(children: [widget.child, const CallOverlay()]),
      ),
    );
  }
}
