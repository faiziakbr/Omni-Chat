import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/ice_config.dart';
import 'call_models.dart';

enum PeerState { connecting, connected, disconnected, failed, closed }

class MediaAccessFailure implements Exception {
  const MediaAccessFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Owns one peer connection plus the local/remote media. One call at a time.
class WebRtcService {
  RTCPeerConnection? _pc;
  MediaStream? _local;
  MediaStream? _remote;
  bool _remoteDescriptionSet = false;
  final List<IceCandidateData> _pendingRemote = [];

  final _localCandidates = StreamController<IceCandidateData>.broadcast();
  final _remoteStreams = StreamController<MediaStream>.broadcast();
  final _peerStates = StreamController<PeerState>.broadcast();

  Stream<IceCandidateData> get localCandidates => _localCandidates.stream;
  Stream<MediaStream> get remoteStreams => _remoteStreams.stream;
  Stream<PeerState> get peerStates => _peerStates.stream;

  MediaStream? get localStream => _local;
  MediaStream? get remoteStream => _remote;

  Future<MediaStream> openMedia() async {
    try {
      _local = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
      });
      return _local!;
    } catch (e) {
      throw MediaAccessFailure('Camera/microphone unavailable: $e');
    }
  }

  Future<void> createPeer() async {
    final pc = await createPeerConnection(IceConfig.configuration);
    _pc = pc;
    _remoteDescriptionSet = false;
    _pendingRemote.clear();

    pc.onIceCandidate = (c) {
      final cand = c.candidate;
      if (cand == null || cand.isEmpty) return; // end-of-candidates
      _localCandidates.add(
        IceCandidateData(candidate: cand, sdpMid: c.sdpMid, sdpMLineIndex: c.sdpMLineIndex),
      );
    };
    pc.onTrack = (event) {
      if (event.streams.isEmpty) return;
      _remote = event.streams.first;
      _remoteStreams.add(_remote!);
    };
    pc.onConnectionState = (s) => _peerStates.add(switch (s) {
      RTCPeerConnectionState.RTCPeerConnectionStateConnected => PeerState.connected,
      RTCPeerConnectionState.RTCPeerConnectionStateDisconnected => PeerState.disconnected,
      RTCPeerConnectionState.RTCPeerConnectionStateFailed => PeerState.failed,
      RTCPeerConnectionState.RTCPeerConnectionStateClosed => PeerState.closed,
      _ => PeerState.connecting,
    });

    final local = _local;
    if (local != null) {
      for (final track in local.getTracks()) {
        await pc.addTrack(track, local);
      }
    }
  }

  Future<SessionDescription> createOffer() async {
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    return SessionDescription(sdp: offer.sdp!, type: offer.type!);
  }

  Future<SessionDescription> createAnswer(SessionDescription offer) async {
    await _setRemote(offer);
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    return SessionDescription(sdp: answer.sdp!, type: answer.type!);
  }

  Future<void> acceptAnswer(SessionDescription answer) async {
    if (_remoteDescriptionSet) return;
    await _setRemote(answer);
  }

  bool get hasRemoteDescription => _remoteDescriptionSet;

  /// Candidates can arrive before the remote description; buffer them.
  Future<void> addRemoteCandidate(IceCandidateData c) async {
    if (_pc == null) return;
    if (!_remoteDescriptionSet) {
      _pendingRemote.add(c);
      return;
    }
    await _addCandidate(c);
  }

  Future<void> _setRemote(SessionDescription d) async {
    await _pc!.setRemoteDescription(RTCSessionDescription(d.sdp, d.type));
    _remoteDescriptionSet = true;
    final pending = List.of(_pendingRemote);
    _pendingRemote.clear();
    for (final c in pending) {
      await _addCandidate(c);
    }
  }

  Future<void> _addCandidate(IceCandidateData c) async {
    try {
      await _pc!.addCandidate(RTCIceCandidate(c.candidate, c.sdpMid, c.sdpMLineIndex));
    } catch (e) {
      debugPrint('addCandidate failed: $e');
    }
  }

  void setMicEnabled(bool on) {
    for (final t in _local?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = on;
    }
  }

  void setCameraEnabled(bool on) {
    for (final t in _local?.getVideoTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = on;
    }
  }

  Future<void> switchCamera() async {
    final tracks = _local?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (tracks.isNotEmpty) await Helper.switchCamera(tracks.first);
  }

  /// Routes call audio to the loudspeaker or the earpiece. Mobile only; a
  /// connected headset still wins when the speaker is off.
  Future<void> setSpeakerOn(bool on) async {
    if (kIsWeb) return;
    try {
      await Helper.setSpeakerphoneOn(on);
    } catch (e) {
      debugPrint('setSpeakerphoneOn failed: $e');
    }
  }

  /// Stops all media and closes the connection. Safe to call repeatedly.
  Future<void> close() async {
    final pc = _pc;
    _pc = null;
    _remoteDescriptionSet = false;
    _pendingRemote.clear();
    for (final stream in [_local, _remote]) {
      if (stream == null) continue;
      for (final t in stream.getTracks()) {
        try {
          await t.stop();
        } catch (_) {}
      }
      try {
        await stream.dispose();
      } catch (_) {}
    }
    _local = null;
    _remote = null;
    try {
      await pc?.close();
    } catch (_) {}
  }
}
