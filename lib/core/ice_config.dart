/// ICE servers for WebRTC. TURN is optional and passed at build time:
/// --dart-define=TURN_URL=turn:host:3478 --dart-define=TURN_USER=u --dart-define=TURN_PASS=p
abstract final class IceConfig {
  static const _turnUrl = String.fromEnvironment('TURN_URL');
  static const _turnUser = String.fromEnvironment('TURN_USER');
  static const _turnPass = String.fromEnvironment('TURN_PASS');

  static Map<String, dynamic> get configuration => {
    'iceServers': [
      {
        'urls': ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302'],
      },
      if (_turnUrl.isNotEmpty) {'urls': _turnUrl, 'username': _turnUser, 'credential': _turnPass},
    ],
    'sdpSemantics': 'unified-plan',
  };
}
