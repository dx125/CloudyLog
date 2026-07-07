import '../data/event_store.dart';
import '../domain/badges.dart';
import '../domain/puff_event.dart';
import '../domain/streaks.dart' as streaks;

/// Everything the free 7-day view needs plus the Pro overview, derived from
/// the local event log in one pass. All charts compute locally — the app is
/// fully functional without an account.
class StatsSnapshot {
  const StatsSnapshot({
    required this.weekCounts,
    required this.weekTotal,
    required this.currentStreak,
    required this.totalCount,
    required this.bestDayCount,
    required this.badgeFacts,
    required this.dayCounts,
  });

  /// Last 7 local days, oldest first (index 6 = today).
  final List<int> weekCounts;
  final int weekTotal;
  final int currentStreak;
  final int totalCount;
  final int bestDayCount;
  final BadgeFacts badgeFacts;
  final Map<DateTime, int> dayCounts;
}

class WrappedFacts {
  const WrappedFacts({
    required this.year,
    required this.totalCount,
    required this.bestDayCount,
    required this.longestStreak,
    required this.topTag,
  });

  final int year;
  final int totalCount;
  final int bestDayCount;
  final int longestStreak;
  final String? topTag;
}

class StatsService {
  StatsService(this._store, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final EventStore _store;
  final DateTime Function() _clock;

  Future<StatsSnapshot> snapshot() async {
    final now = _clock();
    final today = dayOf(now);
    final dayCounts = await _store.countsByDay();
    final days = dayCounts.keys.toSet();

    final weekCounts = List<int>.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      return dayCounts[day] ?? 0;
    });

    var total = 0;
    var best = 0;
    for (final count in dayCounts.values) {
      total += count;
      if (count > best) best = count;
    }

    final events = await _store.allEvents();
    final classicUsed = <String>{};
    for (final event in events) {
      for (final tag in event.tags) {
        if (kClassicTags.contains(tag)) classicUsed.add(tag);
      }
    }

    return StatsSnapshot(
      weekCounts: weekCounts,
      weekTotal: weekCounts.fold(0, (a, b) => a + b),
      currentStreak: streaks.currentStreak(days, now),
      totalCount: total,
      bestDayCount: best,
      dayCounts: dayCounts,
      badgeFacts: BadgeFacts(
        totalCount: total,
        bestDayCount: best,
        longestStreak: streaks.longestStreak(days),
        daysLogged: days.length,
        distinctClassicTagsUsed: classicUsed.length,
      ),
    );
  }

  /// Hour-of-day histogram over the last 30 days (Pro: "Time of day").
  Future<List<int>> hourHistogram() async {
    final now = _clock();
    final from = dayOf(now).subtract(const Duration(days: 30));
    final events = await _store.eventsBetween(from, now);
    final buckets = List<int>.filled(24, 0);
    for (final event in events) {
      if (event.type != kTootType) continue;
      buckets[event.occurredAt.hour]++;
    }
    return buckets;
  }

  /// Average per weekday over the last 8 weeks (Pro: "Weekday patterns").
  /// Index 0 = Monday.
  Future<List<double>> weekdayAverages() async {
    final now = _clock();
    final today = dayOf(now);
    final from = today.subtract(const Duration(days: 56));
    final dayCounts = await _store.countsByDay();
    final sums = List<int>.filled(7, 0);
    final occurrences = List<int>.filled(7, 0);
    for (var day = from;
        !day.isAfter(today);
        day = day.add(const Duration(days: 1))) {
      final index = day.weekday - 1;
      occurrences[index]++;
      sums[index] += dayCounts[day] ?? 0;
    }
    return List<double>.generate(
      7,
      (i) => occurrences[i] == 0 ? 0 : sums[i] / occurrences[i],
    );
  }

  Future<WrappedFacts> wrapped() async {
    final now = _clock();
    final events = await _store.allEvents();
    final thisYear = events
        .where((e) => e.type == kTootType && e.occurredAt.year == now.year)
        .toList();

    final dayCounts = <DateTime, int>{};
    final tagCounts = <String, int>{};
    for (final event in thisYear) {
      final day = dayOf(event.occurredAt);
      dayCounts[day] = (dayCounts[day] ?? 0) + 1;
      for (final tag in event.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }

    String? topTag;
    var topTagCount = 0;
    for (final entry in tagCounts.entries) {
      if (entry.value > topTagCount) {
        topTag = entry.key;
        topTagCount = entry.value;
      }
    }

    var best = 0;
    for (final count in dayCounts.values) {
      if (count > best) best = count;
    }

    return WrappedFacts(
      year: now.year,
      totalCount: thisYear.length,
      bestDayCount: best,
      longestStreak: streaks.longestStreak(dayCounts.keys.toSet()),
      topTag: topTag,
    );
  }
}
