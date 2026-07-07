/// Midpoint percentile rank over a histogram {"count": users}: how "high"
/// [count] scores as 0–100. Ties contribute half their mass, so "everyone
/// tied" maps to 50 — more honest than strict-below.
int percentileRankFor(int count, Map<String, int> distribution) {
  var total = 0;
  var below = 0;
  var equal = 0;
  for (final entry in distribution.entries) {
    final bucket = int.tryParse(entry.key);
    final users = entry.value;
    if (bucket == null || users <= 0) continue;
    total += users;
    if (bucket < count) {
      below += users;
    } else if (bucket == count) {
      equal += users;
    }
  }
  if (total == 0) return 0;
  return ((below + equal / 2) / total * 100).round();
}

/// The free tier's world comparison: a sourced healthy range, fully offline.
/// ("Most people land between 10 and 20 a day.")
const int kWorldRangeLow = 10;
const int kWorldRangeHigh = 20;

enum WorldPace { quiet, onPace, breezy }

WorldPace worldPaceFor(int todayCount) {
  if (todayCount < kWorldRangeLow) return WorldPace.quiet;
  if (todayCount <= kWorldRangeHigh) return WorldPace.onPace;
  return WorldPace.breezy;
}
