import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/widgets/user_avatar.dart';
import '../bloc/call_bloc.dart';

/// Sits above every signed-in route; shows the call UI whenever a call exists.
class CallOverlay extends StatelessWidget {
  const CallOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final visible = context.select((CallBloc b) => b.state.phase != CallPhase.idle);
    return visible ? const CallScreen() : const SizedBox.shrink();
  }
}

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  bool _renderersReady = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    if (!mounted) return;
    setState(() => _renderersReady = true);
    _attach(context.read<CallBloc>().state);
  }

  void _attach(CallState state) {
    if (!_renderersReady) return;
    if (_localRenderer.srcObject != state.localStream) {
      _localRenderer.srcObject = state.localStream;
    }
    if (_remoteRenderer.srcObject != state.remoteStream) {
      _remoteRenderer.srcObject = state.remoteStream;
    }
  }

  @override
  void dispose() {
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CallBloc, CallState>(
      listenWhen: (p, c) => p.localStream != c.localStream || p.remoteStream != c.remoteStream,
      listener: (_, state) => _attach(state),
      builder: (context, state) {
        final showRemote =
            state.remoteStream != null &&
            (state.phase == CallPhase.active || state.phase == CallPhase.connecting);
        final showLocalFull = !showRemote && state.localStream != null && state.cameraOn;

        return Material(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (showRemote && _renderersReady)
                RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              else if (showLocalFull && _renderersReady)
                Opacity(
                  opacity: 0.55,
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                )
              else
                const _Backdrop(),

              // Dim top and bottom so text and buttons stay readable over video.
              const _Scrims(),

              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    if (!showRemote) ...[
                      UserAvatar(name: state.peerName, radius: 48),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      state.peerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _StatusLine(state: state),
                    const Spacer(),
                    _Controls(state: state),
                    const SizedBox(height: 32),
                  ],
                ),
              ),

              if (showRemote && _renderersReady && state.localStream != null)
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 16,
                  right: 16,
                  child: _LocalPip(renderer: _localRenderer, cameraOn: state.cameraOn),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Theme.of(context).colorScheme.primary.withValues(alpha: 0.6), Colors.black],
        ),
      ),
    );
  }
}

class _Scrims extends StatelessWidget {
  const _Scrims();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black54, Colors.transparent, Colors.transparent, Colors.black54],
            stops: [0, 0.25, 0.7, 1],
          ),
        ),
      ),
    );
  }
}

class _LocalPip extends StatelessWidget {
  const _LocalPip({required this.renderer, required this.cameraOn});
  final RTCVideoRenderer renderer;
  final bool cameraOn;

  @override
  Widget build(BuildContext context) {
    final small = MediaQuery.sizeOf(context).width < 600;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: small ? 96 : 160,
        height: small ? 128 : 120,
        color: Colors.black87,
        child: cameraOn
            ? RTCVideoView(
                renderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            : const Icon(Icons.videocam_off, color: Colors.white54),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});
  final CallState state;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: Colors.white70, fontSize: 15);
    return switch (state.phase) {
      CallPhase.outgoing => const Text('Calling…', style: style),
      CallPhase.incoming => const Text('Incoming video call', style: style),
      CallPhase.connecting => const Text('Connecting…', style: style),
      CallPhase.active =>
        state.reconnecting
            ? const Text('Reconnecting…', style: style)
            : _CallTimer(since: state.connectedAt!, style: style),
      CallPhase.ended => Text(_endText(state), style: style),
      CallPhase.idle => const SizedBox.shrink(),
    };
  }

  static String _endText(CallState s) => switch (s.endReason) {
    CallEndReason.noAnswer => 'No answer',
    CallEndReason.declinedByPeer => 'Call declined',
    CallEndReason.busy => '${s.peerName} is on another call',
    CallEndReason.missed => 'Missed call',
    CallEndReason.mediaDenied => 'Camera or microphone access was denied',
    CallEndReason.failed => 'Call failed',
    _ => 'Call ended',
  };
}

class _CallTimer extends StatefulWidget {
  const _CallTimer({required this.since, required this.style});
  final DateTime since;
  final TextStyle style;

  @override
  State<_CallTimer> createState() => _CallTimerState();
}

class _CallTimerState extends State<_CallTimer> {
  late final Timer _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    _timer; // start
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text(formatCallDuration(DateTime.now().difference(widget.since)), style: widget.style);
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state});
  final CallState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CallBloc>();
    switch (state.phase) {
      case CallPhase.incoming:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RoundButton(
              icon: Icons.call_end,
              label: 'Decline',
              color: Colors.red,
              onPressed: () => bloc.add(const CallDeclined()),
            ),
            _RoundButton(
              icon: Icons.videocam,
              label: 'Accept',
              color: Colors.green,
              onPressed: () => bloc.add(const CallAccepted()),
            ),
          ],
        );
      case CallPhase.outgoing:
      case CallPhase.connecting:
      case CallPhase.active:
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 16,
          children: [
            _RoundButton(
              icon: state.micOn ? Icons.mic : Icons.mic_off,
              label: state.micOn ? 'Mute' : 'Unmute',
              color: state.micOn ? Colors.white24 : Colors.white,
              iconColor: state.micOn ? Colors.white : Colors.black,
              onPressed: () => bloc.add(const CallMicToggled()),
            ),
            _RoundButton(
              icon: state.cameraOn ? Icons.videocam : Icons.videocam_off,
              label: state.cameraOn ? 'Camera off' : 'Camera on',
              color: state.cameraOn ? Colors.white24 : Colors.white,
              iconColor: state.cameraOn ? Colors.white : Colors.black,
              onPressed: () => bloc.add(const CallCameraToggled()),
            ),
            if (!kIsWeb)
              _RoundButton(
                icon: state.speakerOn ? Icons.volume_up : Icons.phone_in_talk,
                label: state.speakerOn ? 'Speaker' : 'Earpiece',
                color: state.speakerOn ? Colors.white24 : Colors.white,
                iconColor: state.speakerOn ? Colors.white : Colors.black,
                onPressed: () => bloc.add(const CallSpeakerToggled()),
              ),
            if (!kIsWeb)
              _RoundButton(
                icon: Icons.cameraswitch,
                label: 'Flip',
                color: Colors.white24,
                onPressed: () => bloc.add(const CallCameraSwitched()),
              ),
            _RoundButton(
              icon: Icons.call_end,
              label: 'End',
              color: Colors.red,
              onPressed: () => bloc.add(const CallHungUp()),
            ),
          ],
        );
      case CallPhase.ended:
      case CallPhase.idle:
        return const SizedBox(height: 96);
    }
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 64,
          child: IconButton.filled(
            tooltip: label,
            style: IconButton.styleFrom(backgroundColor: color, foregroundColor: iconColor),
            iconSize: 28,
            onPressed: onPressed,
            icon: Icon(icon),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
