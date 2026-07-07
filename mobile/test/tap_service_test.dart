import 'package:flutter_test/flutter_test.dart';
import 'package:puff/domain/puff_event.dart';
import 'package:puff/services/tap_service.dart';

import 'fakes.dart';

void main() {
  group('TapService', () {
    late InMemoryEventStore store;
    late DateTime now;
    late TapService service;

    setUp(() async {
      store = InMemoryEventStore();
      now = DateTime(2026, 7, 7, 10, 0, 0);
      service = TapService(store, deviceId: 'dev-1', clock: () => now);
      await service.load();
    });

    test('starts at zero and loads existing count', () async {
      expect(service.todayCount, 0);
      await store.insert(PuffEvent(id: 'x', occurredAt: now));
      final fresh = TapService(store, deviceId: 'dev-1', clock: () => now);
      await fresh.load();
      expect(fresh.todayCount, 1);
    });

    test('tap bumps the count and appends an event', () async {
      await service.tap();
      await service.tap();
      expect(service.todayCount, 2);
      expect(store.events.length, 2);
      final event = store.events.values.first;
      expect(event.type, kTootType);
      expect(event.deviceId, 'dev-1');
      expect(event.syncedAt, isNull);
    });

    test('events get time-ordered unique ids', () async {
      await service.tap();
      await service.tap();
      final ids = store.events.keys.toList();
      expect(ids.toSet().length, 2);
    });

    test('quick tags apply to the last log within the window', () async {
      await service.tap();
      expect(service.canTagLastEvent, isTrue);

      now = now.add(const Duration(seconds: 5));
      await service.toggleTagOnLastEvent('silent');
      await service.toggleTagOnLastEvent('thunder');
      await service.toggleTagOnLastEvent('silent'); // toggle off

      final event = store.events.values.single;
      expect(event.tags, ['thunder']);
      expect(service.lastEventTags, ['thunder']);
    });

    test('the tag window closes after 10 seconds', () async {
      await service.tap();
      now = now.add(const Duration(seconds: 11));
      expect(service.canTagLastEvent, isFalse);
      await service.toggleTagOnLastEvent('silent');
      expect(store.events.values.single.tags, isEmpty);
    });

    test('day rollover resets the live count but keeps history', () async {
      await service.tap();
      expect(service.todayCount, 1);

      now = DateTime(2026, 7, 8, 0, 5);
      await service.refreshIfStale();
      expect(service.todayCount, 0);

      await service.tap();
      expect(service.todayCount, 1);
      expect(store.events.length, 2);
    });

    test('tapping right after midnight rolls the day itself', () async {
      await service.tap();
      now = DateTime(2026, 7, 8, 0, 1);
      await service.tap();
      expect(service.todayCount, 1);
    });
  });
}
