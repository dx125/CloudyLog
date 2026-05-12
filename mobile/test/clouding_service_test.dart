import 'package:cloudy_log/data/clouding_repository.dart';
import 'package:cloudy_log/data/models/clouding_entry.dart';
import 'package:cloudy_log/services/clouding_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryCloudingRepository implements CloudingRepository {
  final Map<String, int> _store = {};

  String _key(String userId, DateTime date) =>
      '${userId}_${CloudingEntry.dateKey(date)}';

  @override
  Future<int> getCountFor(String userId, DateTime date) async {
    return _store[_key(userId, date)] ?? 0;
  }

  @override
  Future<void> setCountFor(String userId, DateTime date, int count) async {
    _store[_key(userId, date)] = count;
  }

  @override
  Future<Map<DateTime, int>> getAllEntries(String userId) async {
    final entries = <DateTime, int>{};
    final prefix = '${userId}_';
    _store.forEach((key, value) {
      if (!key.startsWith(prefix)) return;
      final parts = key.substring(prefix.length).split('-');
      if (parts.length != 3) return;
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y == null || m == null || d == null) return;
      entries[DateTime(y, m, d)] = value;
    });
    return entries;
  }
}

const _userId = 'user-1';

void main() {
  group('CloudingService', () {
    late _InMemoryCloudingRepository repo;
    late CloudingService service;

    setUp(() async {
      repo = _InMemoryCloudingRepository();
      service = CloudingService(repo);
      await service.loadFor(_userId);
    });

    test('starts at zero when no data', () {
      expect(service.todayCount, 0);
      expect(service.isLoaded, isTrue);
      expect(service.currentUserId, _userId);
    });

    test('increment adds to today and persists', () async {
      await service.increment();
      await service.increment();
      expect(service.todayCount, 2);
      expect(await repo.getCountFor(_userId, DateTime.now()), 2);
    });

    test('resetToday wipes the count', () async {
      await service.increment();
      await service.increment();
      await service.resetToday();
      expect(service.todayCount, 0);
      expect(await repo.getCountFor(_userId, DateTime.now()), 0);
    });

    test('loads the existing count for today', () async {
      await repo.setCountFor(_userId, DateTime.now(), 7);
      final fresh = CloudingService(repo);
      await fresh.loadFor(_userId);
      expect(fresh.todayCount, 7);
    });

    test('fetchHistory returns every stored day for the user', () async {
      final d1 = DateTime(2026, 4, 18);
      final d2 = DateTime(2026, 4, 19);
      final d3 = DateTime(2026, 4, 20);
      await repo.setCountFor(_userId, d1, 10);
      await repo.setCountFor(_userId, d2, 35);
      await repo.setCountFor(_userId, d3, 50);

      final history = await service.fetchHistory();
      expect(history, {d1: 10, d2: 35, d3: 50});
    });

    test('does not surface other users\' history', () async {
      final today = DateTime.now();
      await repo.setCountFor('someone-else', today, 99);
      await service.increment();

      final history = await service.fetchHistory();
      expect(history.values, contains(1));
      expect(history.values, isNot(contains(99)));
    });

    test('clear drops in-memory state', () async {
      await service.increment();
      await service.clear();
      expect(service.isLoaded, isFalse);
      expect(service.currentUserId, isNull);
      expect(service.todayCount, 0);
    });

    test('throws if used before loadFor', () async {
      final fresh = CloudingService(repo);
      expect(fresh.increment, throwsStateError);
    });

    test('switching users isolates counts', () async {
      await service.increment();
      await service.increment();
      expect(service.todayCount, 2);

      await service.clear();
      await service.loadFor('user-2');
      expect(service.todayCount, 0);

      await service.increment();
      expect(service.todayCount, 1);

      await service.clear();
      await service.loadFor(_userId);
      expect(service.todayCount, 2);
    });
  });
}
