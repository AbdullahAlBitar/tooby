/// Formats a duration as `m:ss` or `h:mm:ss`.
String formatDuration(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// Parses `m:ss` / `h:mm:ss` strings (as stored in the videos table).
Duration? parseDurationString(String? value) {
  if (value == null || value.isEmpty) return null;
  final parts = value.split(':').map(int.tryParse).toList();
  if (parts.any((p) => p == null)) return null;
  int seconds = 0;
  for (final p in parts) {
    seconds = seconds * 60 + p!;
  }
  return Duration(seconds: seconds);
}
