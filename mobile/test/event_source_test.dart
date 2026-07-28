import 'package:flutter_test/flutter_test.dart';
import 'package:puff/data/event_store.dart';
import 'package:puff/domain/puff_event.dart';
import 'package:puff/services/global_stats_service.dart';
import 'package:puff/services/stats_service.dart';

import 'fakes.dart';

/// The boundary from migration 0007: heard events are real logs the user can
/// see and undo, but they are never health data. Streaks, badges, charts,
/// Wrapped and — above all — the world aggregate must not see them.
///
/// If one of these tests fails, the app is quietly reporting furniture noise as
/// population health data. Fix the query, not the test.
void main() {
  final today = DateTime(2026, 7, 20, 12);
  DateTime clock() => today;

  PuffEvent tapped(String id, DateTime at) =>
      PuffEvent(id: id, occurredAt: at, source: EventSource.tap);
  PuffEvent heard(String id, DateTime at) =>
      PuffEvent(id: id, occurredAt: at, source: EventSource.heard);

  group('SourceFilter', () {
    test('matches the intended sources', () {
      expect(SourceFilter.tapped.matches(EventSource.tap), isTrue);
      expect(SourceFilter.tapped.matches(EventSource.heard), isFalse);
      expect(SourceFilter.heard.matches(EventSource.heard), isTrue);
      expect(SourceFilter.heard.matches(EventSource.tap), isFalse);
      expect(SourceFilter.all.matches(EventSource.tap), isTrue);
      expect(SourceFilter.all.matches(EventSource.heard), isTrue);
    });

    test('events default to tapped', () {
      expect(PuffEvent(id: 'a', occurredAt: today).source, EventSource.tap);
    });

    test('an unknown or missing stored source reads as tapped', () {
      expect(sourceFrom(null), EventSource.tap);
      expect(sourceFrom('tap'), EventSource.tap);
      expect(sourceFrom('heard'), EventSource.heard);
      expect(sourceFrom('something-new'), EventSource.tap);
    });

    test('copyWith carries source through a tag edit', () {
      final event = heard('h', today).copyWith(tags: ['thunder']);
      expect(event.source, EventSource.heard);
      expect(event.tags, ['thunder']);
    });
  });

  group('EventStore queries', () {
    late InMemoryEventStore store;

    setUp(() async {
      store = InMemoryEventStore();
      await store.insert(tapped('t1', today));
      await store.insert(tapped('t2', today));
      await store.insert(heard('h1', today));
    });

    test('countForDay is tapped-only by default', () async {
      expect(await store.countForDay(today), 2);
      expect(await store.countForDay(today, source: SourceFilter.heard), 1);
      expect(await store.countForDay(today, source: SourceFilter.all), 3);
    });

    test('countsByDay is tapped-only by default', () async {
      final tappedCounts = await store.countsByDay();
      expect(tappedCounts[dayOf(today)], 2);

      final heardCounts = await store.countsByDay(source: SourceFilter.heard);
      expect(heardCounts[dayOf(today)], 1);
    });

    test('allEvents returns everything unless scoped', () async {
      expect((await store.allEvents()).length, 3);
      expect((await store.allEvents(source: SourceFilter.tapped)).length, 2);
    });

    test('delete removes an event outright', () async {
      await store.delete('h1');
      expect(await store.countForDay(today, source: SourceFilter.all), 2);
    });
  });

  group('StatsService excludes heard events', () {
    test('streaks, totals and the week chart count taps only', () async {
      final store = InMemoryEventStore();
      // Three tapped days in a row, plus a pile of heard events on a day that
      // would otherwise extend the streak.
      for (var back = 0; back < 3; back++) {
        await store.insert(
          tapped('t$back', today.subtract(Duration(days: back))),
        );
      }
      for (var i = 0; i < 5; i++) {
        await store.insert(heard('h$i', today.subtract(const Duration(days: 3))));
      }

      final snapshot = await StatsService(store, clock: clock).snapshot();
      expect(snapshot.totalCount, 3);
      expect(snapshot.currentStreak, 3,
          reason: 'heard events must not extend a streak');
      expect(snapshot.weekCounts.reduce((a, b) => a + b), 3);
      expect(snapshot.badgeFacts.totalCount, 3);
    });

    test('wrapped counts taps only', () async {
      final store = InMemoryEventStore();
      await store.insert(tapped('t1', today));
      await store.insert(heard('h1', today));
      await store.insert(heard('h2', today));

      final wrapped = await StatsService(store, clock: clock).wrapped();
      expect(wrapped.totalCount, 1);
      expect(wrapped.bestDayCount, 1);
    });

    test('the hour histogram counts taps only', () async {
      final store = InMemoryEventStore();
      // eventsBetween's upper bound is exclusive, so sit an hour behind `now`.
      final earlier = today.subtract(const Duration(hours: 1));
      await store.insert(tapped('t1', earlier));
      await store.insert(heard('h1', earlier));

      final hours = await StatsService(store, clock: clock).hourHistogram();
      expect(hours[11], 1);
    });
  });

  group('world stats never receive heard events', () {
    test('reportIfDue reports the tapped count only', () async {
      final store = InMemoryEventStore();
      final gateway = FakeGlobalStatsGateway();
      final settings = InMemorySettingsRepository();

      await store.insert(tapped('t1', today));
      await store.insert(tapped('t2', today));
      for (var i = 0; i < 10; i++) {
        await store.insert(heard('h$i', today));
      }

      final service = GlobalStatsService(gateway, store, settings,
          clock: clock);
      final reported = await service.reportIfDue();

      expect(reported, isTrue);
      expect(gateway.reports.single.single.count, 2,
          reason: 'ten heard events must not reach the world aggregate');
    });

    test('a day of only heard events reports nothing at all', () async {
      final store = InMemoryEventStore();
      final gateway = FakeGlobalStatsGateway();
      final settings = InMemorySettingsRepository();

      await store.insert(heard('h1', today));
      await store.insert(heard('h2', today));

      final service = GlobalStatsService(gateway, store, settings,
          clock: clock);
      final reported = await service.reportIfDue();

      expect(reported, isFalse);
      expect(gateway.reports, isEmpty);
    });
  });
}
