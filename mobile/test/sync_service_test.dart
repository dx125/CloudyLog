import 'package:cloudy_log/data/api/api_client.dart';
import 'package:cloudy_log/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  group('SyncService', () {
    late FakeCloudingSyncGateway gateway;
    late InMemoryCloudingRepository local;
    late SyncService service;

    final d1 = DateTime(2026, 7, 1);
    final d2 = DateTime(2026, 7, 2);

    setUp(() {
      gateway = FakeCloudingSyncGateway();
      local = InMemoryCloudingRepository();
      service = SyncService(gateway, local);
    });

    test('syncAll uploads local history and pulls the merged view', () async {
      await local.setCountFor('local', d1, 10);
      gateway.server[d2] = 40; // server-only day

      final ok = await service.syncAll('local');

      expect(ok, isTrue);
      expect(gateway.server[d1], 10);
      expect(await local.getCountFor('local', d2), 40);
      expect(service.lastSyncedAt, isNotNull);
    });

    test('merge keeps the larger count per day', () async {
      await local.setCountFor('local', d1, 5);
      gateway.server[d1] = 20;

      await service.syncAll('local');

      expect(await local.getCountFor('local', d1), 20);
      expect(gateway.server[d1], 20);
    });

    test('syncAll reports failure when offline', () async {
      gateway.failWith = const ApiException.network();
      expect(await service.syncAll('local'), isFalse);
    });

    test('pushToday deduplicates identical pushes', () async {
      final today = DateTime(2026, 7, 6);
      await service.pushToday(today, 3);
      await service.pushToday(today, 3);
      await service.pushToday(today, 4);
      expect(gateway.pushedTodayCounts, [3, 4]);
    });

    test('pushToday retries after a failed push', () async {
      final today = DateTime(2026, 7, 6);
      gateway.failWith = const ApiException.network();
      await service.pushToday(today, 3);
      gateway.failWith = null;
      await service.pushToday(today, 3);
      expect(gateway.pushedTodayCounts, [3]);
    });
  });
}
