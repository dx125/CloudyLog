import 'package:flutter/foundation.dart';

import '../data/event_store.dart';
import '../data/gateways.dart';
import '../data/settings_repository.dart';
import '../domain/puff_event.dart';

/// World-stats participation for every tier (raw event sync stays Pro-only —
/// this is one number per day, not sync). Two jobs:
///
///  * cache the latest anonymous aggregate for the stats screen;
///  * once per local day (background at startup), report this device's
///    recent daily toot counts so the aggregates cover free users too.
class GlobalStatsService extends ChangeNotifier {
  GlobalStatsService(
    this._gateway,
    this._store,
    this._settings, {
    DateTime Function()? clock,
    this.refreshTtl = const Duration(minutes: 15),
    this.reportWindowDays = 7,
  }) : _clock = clock ?? DateTime.now;

  /// Server-side ceiling (user_daily_stats check constraint). Clamp rather
  /// than let one absurd day void the whole report.
  static const int _maxDailyCount = 1000;

  final GlobalStatsGateway _gateway;
  final EventStore _store;
  final SettingsRepository _settings;
  final DateTime Function() _clock;
  final Duration refreshTtl;

  /// Days re-sent per report; the overlap heals days the app wasn't opened
  /// and finalizes yesterday's partial "today".
  final int reportWindowDays;

  GlobalDailyStats? _latest;
  bool _loading = false;
  DateTime? _fetchedAt;

  GlobalDailyStats? get latest => _latest;
  bool get isLoading => _loading;

  /// Fetches the newest aggregate; a no-op while the cached one is fresh.
  /// Offline keeps the last value (the failure is recorded at the gateway).
  Future<void> refresh({bool force = false}) async {
    if (_loading) return;
    final now = _clock();
    if (!force &&
        _fetchedAt != null &&
        now.difference(_fetchedAt!) < refreshTtl) {
      return;
    }
    _loading = true;
    notifyListeners();
    try {
      _latest = await _gateway.latest();
      _fetchedAt = now;
    } on CloudUnavailable {
      // The stats screen degrades to the sourced world range.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Once per local day, pushes the last [reportWindowDays] days' nonzero
  /// counts. Today's partial count goes out too — tomorrow's upsert corrects
  /// it. Returns true when a report went out; offline leaves the day unmarked
  /// so the next launch retries.
  Future<bool> reportIfDue() async {
    final today = dayOf(_clock());
    final todayKey = dayKey(today);
    if (await _settings.lastStatsReportDay() == todayKey) return false;

    final counts = await _store.countsByDay();
    final days = <DailyTootCount>[
      for (var back = reportWindowDays - 1; back >= 0; back--)
        if ((counts[today.subtract(Duration(days: back))] ?? 0) > 0)
          DailyTootCount(
            day: today.subtract(Duration(days: back)),
            count: counts[today.subtract(Duration(days: back))]!
                .clamp(1, _maxDailyCount),
          ),
    ];
    try {
      if (days.isNotEmpty) await _gateway.reportDaily(days);
      await _settings.setLastStatsReportDay(todayKey);
      return days.isNotEmpty;
    } on CloudUnavailable {
      return false;
    }
  }
}
