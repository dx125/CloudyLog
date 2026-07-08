import 'package:flutter_test/flutter_test.dart';
import 'package:puff/data/gateways.dart';
import 'package:puff/domain/puff_event.dart';
import 'package:puff/services/global_stats_service.dart';

import 'fakes.dart';

void main() {
  final now = DateTime(2026, 7, 8, 14, 30);
  final today = DateTime(2026, 7, 8);

  late InMemoryEventStore store;
  late InMemorySettingsRepository settings;
  late FakeGlobalStatsGateway gateway;
  late GlobalStatsService service;

  setUp(() {
    store = InMemoryEventStore();
    settings = InMemorySettingsRepository();
    gateway = FakeGlobalStatsGateway();
    service = GlobalStatsService(gateway, store, settings, clock: () => now);
  });

  Future<void> seed(DateTime day, int count) async {
    for (var i = 0; i < count; i++) {
      await store.insert(PuffEvent(
        id: '${dayKey(day)}-$i',
        occurredAt: day.add(Duration(minutes: i)),
      ));
    }
  }

  group('reportIfDue', () {
    test('pushes the recent nonzero days once per local day', () async {
      await seed(today, 3);
      await seed(today.subtract(const Duration(days: 1)), 2);
      await seed(today.subtract(const Duration(days: 10)), 5); // outside window

      expect(await service.reportIfDue(), isTrue);

      expect(gateway.reports, hasLength(1));
      final report = gateway.reports.single;
      expect(report, hasLength(2));
      expect(report.first.day, today.subtract(const Duration(days: 1)));
      expect(report.first.count, 2);
      expect(report.last.day, today);
      expect(report.last.count, 3);
      expect(settings.lastReportDay, '2026-07-08');

      // Same day again: already reported, nothing new goes out.
      expect(await service.reportIfDue(), isFalse);
      expect(gateway.reports, hasLength(1));
    });

    test('offline leaves the day unmarked so the next launch retries',
        () async {
      await seed(today, 4);
      gateway.offline = true;

      expect(await service.reportIfDue(), isFalse);
      expect(settings.lastReportDay, isNull);

      gateway.offline = false;
      expect(await service.reportIfDue(), isTrue);
      expect(gateway.reports.single.single.count, 4);
      expect(settings.lastReportDay, '2026-07-08');
    });

    test('nothing to report still marks the day and skips the network',
        () async {
      expect(await service.reportIfDue(), isFalse);
      expect(gateway.reports, isEmpty);
      expect(settings.lastReportDay, '2026-07-08');
    });

    test('clamps an implausible day to the server ceiling', () async {
      await seed(today, 1200);

      await service.reportIfDue();

      expect(gateway.reports.single.single.count, 1000);
    });
  });

  group('refresh', () {
    final aggregate = GlobalDailyStats(
      day: today,
      totalUsers: 42,
      distribution: const {'12': 42},
    );

    test('fetches once and honors the TTL until forced', () async {
      gateway.stats = aggregate;

      await service.refresh();
      expect(service.latest?.totalUsers, 42);
      expect(gateway.latestCalls, 1);

      await service.refresh(); // fresh — no second call
      expect(gateway.latestCalls, 1);

      await service.refresh(force: true);
      expect(gateway.latestCalls, 2);
    });

    test('offline keeps the last aggregate', () async {
      gateway.stats = aggregate;
      await service.refresh();

      gateway.offline = true;
      await service.refresh(force: true);

      expect(service.latest?.totalUsers, 42);
      expect(service.isLoading, isFalse);
    });
  });
}
