/// Short relative/clock formatting without pulling in intl patterns.
String formatClock(DateTime t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String formatLastSeen(DateTime? t) {
  if (t == null) return 'offline';
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'last seen just now';
  if (diff.inHours < 1) return 'last seen ${diff.inMinutes} min ago';
  if (diff.inDays < 1) return 'last seen today at ${formatClock(t)}';
  if (diff.inDays == 1) return 'last seen yesterday';
  return 'last seen ${t.day}/${t.month}/${t.year}';
}
