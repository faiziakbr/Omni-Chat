/// Stable id for a 1v1 conversation, independent of who calls it.
String chatIdFor(String a, String b) => a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';
