import 'puff_event.dart';

/// Current streak: consecutive days with at least one toot, ending today or
/// yesterday (an empty today doesn't break the streak until midnight).
int currentStreak(Set<DateTime> daysWithEvents, DateTime now) {
  final days = daysWithEvents.map(dayOf).toSet();
  var cursor = dayOf(now);
  if (!days.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// Longest streak anywhere in history (Wrapped, badges).
int longestStreak(Set<DateTime> daysWithEvents) {
  final days = daysWithEvents.map(dayOf).toSet();
  var longest = 0;
  for (final day in days) {
    // Only count from the start of a run.
    if (days.contains(day.subtract(const Duration(days: 1)))) continue;
    var length = 0;
    var cursor = day;
    while (days.contains(cursor)) {
      length++;
      cursor = cursor.add(const Duration(days: 1));
    }
    if (length > longest) longest = length;
  }
  return longest;
}
