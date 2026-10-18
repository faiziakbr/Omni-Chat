import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'call_ringer.dart';

/// Plays looping bundled tones. Base for the platform ringers.
class AudioRinger implements CallRinger {
  AudioRinger() {
    _player.setReleaseMode(ReleaseMode.loop);
  }

  final _player = AudioPlayer();
  final _actions = StreamController<RingerAction>.broadcast();

  @override
  Stream<RingerAction> get actions => _actions.stream;

  @override
  Future<void> startIncoming({required String callId, required String callerName}) =>
      _play('sounds/ringtone.wav', volume: 1);

  @override
  Future<void> startRingback() => _play('sounds/ringback.wav', volume: 0.6);

  Future<void> _play(String asset, {required double volume}) async {
    try {
      await _player.stop();
      await _player.setVolume(volume);
      await _player.play(AssetSource(asset));
    } catch (_) {
      // Browsers block audio until the page has had a user gesture.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  @override
  Future<void> connected() async {}

  @override
  Future<void> ended() => stop();

  @override
  Future<void> dispose() async {
    await stop();
    await _player.dispose();
    await _actions.close();
  }
}
