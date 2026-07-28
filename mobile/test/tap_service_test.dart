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

  // The architectural line from migration 0007: heard events are real logs but
  // never health data. These tests exist to make that line expensive to cross.
  group('TapService — heard events', () {
    late InMemoryEventStore store;
    late DateTime now;
    late TapService service;

    setUp(() async {
      store = InMemoryEventStore();
      now = DateTime(2026, 7, 7, 10, 0, 0);
      service = TapService(store, deviceId: 'dev-1', clock: () => now);
      await service.load();
    });

    test('logHeard counts separately from tapped', () async {
      await service.tap();
      await service.logHeard();
      await service.logHeard();

      expect(service.todayCount, 1, reason: 'heard must not inflate the tap count');
      expect(service.todayHeardCount, 2);
      expect(store.events.length, 3);
    });

    test('heard events carry EventSource.heard', () async {
      final id = await service.logHeard();
      expect(store.events[id]!.source, EventSource.heard);
      expect(store.events[id]!.type, kTootType);
    });

    test('heard events never open the quick-tag window', () async {
      await service.logHeard();
      expect(service.canTagLastEvent, isFalse,
          reason: 'the user pressed nothing, so there is no last tap to tag');
    });

    test('a heard log does not disturb an open tag window', () async {
      await service.tap();
      await service.logHeard();

      await service.toggleTagOnLastEvent('thunder');
      final tapped = store.events.values.firstWhere(
        (e) => e.source == EventSource.tap,
      );
      expect(tapped.tags, ['thunder'], reason: 'the tap still owns the window');
    });

    test('undoHeard removes the event entirely', () async {
      final id = await service.logHeard();
      expect(service.todayHeardCount, 1);

      await service.undoHeard(id);
      expect(service.todayHeardCount, 0);
      expect(store.events, isEmpty,
          reason: 'a false positive must leave no trace, including in sync');
    });

    test('undoHeard refuses to delete a tapped event', () async {
      await service.tap();
      final tappedId = store.events.keys.single;

      await service.undoHeard(tappedId);
      expect(store.events.length, 1);
      expect(service.todayCount, 1);
    });

    test('load restores both counts independently', () async {
      await service.tap();
      await service.logHeard();

      final fresh = TapService(store, deviceId: 'dev-1', clock: () => now);
      await fresh.load();
      expect(fresh.todayCount, 1);
      expect(fresh.todayHeardCount, 1);
    });

    test('day rollover resets the heard count too', () async {
      await service.logHeard();
      now = DateTime(2026, 7, 8, 0, 5);
      await service.refreshIfStale();
      expect(service.todayHeardCount, 0);
    });
  });
}
