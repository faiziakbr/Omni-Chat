/// Realtime Database paths. Keep every path string here.
abstract final class RtdbPaths {
  static const connected = '.info/connected';
  static String user(String uid) => 'users/$uid';
  static String emailIndex(String emailKey) => 'emailIndex/$emailKey';
  static String userChats(String uid) => 'userChats/$uid';
  static String presence(String uid) => 'presence/$uid';
  static String inbox(String uid) => 'inbox/$uid';
  static String receipts(String uid) => 'receipts/$uid';
  static String call(String callId) => 'calls/$callId';
  static String incomingCall(String uid) => 'incomingCall/$uid';
}
