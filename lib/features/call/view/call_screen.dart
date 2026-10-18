import 'dart:async';
import 'dart:ui' show ImageFilter;

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
                      const SizedBox(height: 24),
                      _PulsingAvatar(
                        name: state.peerName,
                        pulsing:
                            state.phase == CallPhase.outgoing || state.phase == CallPhase.incoming,
                      ),
                      const SizedBox(height: 28),
                    ],
                    Text(
                      state.peerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
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
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF312E81), Color(0xFF1E1B4B), Color(0xFF0B0B1A)],
          stops: [0, 0.45, 1],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.45),
            radius: 0.9,
            colors: [Color(0x668B5CF6), Color(0x008B5CF6)],
          ),
        ),
      ),
    );
  }
}

/// Large avatar with soft rings rippling out while the call is ringing.
class _PulsingAvatar extends StatefulWidget {
  const _PulsingAvatar({required this.name, required this.pulsing});
  final String name;
  final bool pulsing;

  @override
  State<_PulsingAvatar> createState() => _PulsingAvatarState();
}

class _PulsingAvatarState extends State<_PulsingAvatar> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) _controller.repeat();
  }

  @override
  void didUpdateWidget(_PulsingAvatar old) {
    super.didUpdateWidget(old);
    if (widget.pulsing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.pulsing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const radius = 56.0;
    return SizedBox.square(
      dimension: radius * 3.2,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Stack(
          alignment: Alignment.center,
          children: [
            if (widget.pulsing)
              for (final offset in const [0.0, 0.5])
                _ring(((_controller.value + offset) % 1.0), radius),
            child!,
          ],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 4),
          ),
          child: UserAvatar(name: widget.name, radius: radius),
        ),
      ),
    );
  }

  Widget _ring(double t, double radius) {
    final size = radius * 2 * (1 + t * 0.6);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.12 * (1 - t)),
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
              icon: Icons.call_end_rounded,
              label: 'Decline',
              color: const Color(0xFFEF4444),
              size: 72,
              onPressed: () => bloc.add(const CallDeclined()),
            ),
            _RoundButton(
              icon: Icons.videocam_rounded,
              label: 'Accept',
              color: const Color(0xFF22C55E),
              size: 72,
              onPressed: () => bloc.add(const CallAccepted()),
            ),
          ],
        );
      case CallPhase.outgoing:
      case CallPhase.connecting:
      case CallPhase.active:
        return _GlassPanel(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              _RoundButton(
                icon: state.micOn ? Icons.mic : Icons.mic_off,
                label: state.micOn ? 'Mute' : 'Unmute',
                color: state.micOn ? _glass : Colors.white,
                iconColor: state.micOn ? Colors.white : Colors.black,
                onPressed: () => bloc.add(const CallMicToggled()),
              ),
              _RoundButton(
                icon: state.cameraOn ? Icons.videocam : Icons.videocam_off,
                label: state.cameraOn ? 'Camera off' : 'Camera on',
                color: state.cameraOn ? _glass : Colors.white,
                iconColor: state.cameraOn ? Colors.white : Colors.black,
                onPressed: () => bloc.add(const CallCameraToggled()),
              ),
              if (!kIsWeb)
                _RoundButton(
                  icon: state.speakerOn ? Icons.volume_up : Icons.phone_in_talk,
                  label: state.speakerOn ? 'Speaker' : 'Earpiece',
                  color: state.speakerOn ? _glass : Colors.white,
                  iconColor: state.speakerOn ? Colors.white : Colors.black,
                  onPressed: () => bloc.add(const CallSpeakerToggled()),
                ),
              if (!kIsWeb)
                _RoundButton(
                  icon: Icons.cameraswitch_rounded,
                  label: 'Flip',
                  color: _glass,
                  onPressed: () => bloc.add(const CallCameraSwitched()),
                ),
              _RoundButton(
                icon: Icons.call_end_rounded,
                label: 'End',
                color: const Color(0xFFEF4444),
                onPressed: () => bloc.add(const CallHungUp()),
              ),
            ],
          ),
        );
      case CallPhase.ended:
      case CallPhase.idle:
        return const SizedBox(height: 96);
    }
  }
}

const _glass = Color(0x29FFFFFF);

/// Frosted bar behind the in-call controls so they read over any video.
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white12),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.iconColor = Colors.white,
    this.size = 58,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: size,
          child: IconButton.filled(
            tooltip: label,
            style: IconButton.styleFrom(backgroundColor: color, foregroundColor: iconColor),
            iconSize: size * 0.44,
            onPressed: onPressed,
            icon: Icon(icon),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
