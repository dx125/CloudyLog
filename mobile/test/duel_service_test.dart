import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puff/domain/duel.dart';
import 'package:puff/domain/puff_event.dart';
import 'package:puff/services/duel_service.dart';

import 'fakes.dart';

void main() {
  late InMemoryEventStore store;
  late FakeDuelGateway gateway;
  late FakeDuelChannel channel;
  late DateTime now;

  DuelService build() => DuelService(
        gateway,
        store,
        channel: channel,
        clock: () => now,
      );

  /// A duel currently in progress: started half its window ago, so it's live
  /// regardless of whether that window is three minutes or seven days.
  Duel duelOf({
    DuelKind kind = DuelKind.async,
    Duration window = const Duration(days: 7),
  }) {
    final startsAt = now.subtract(window ~/ 2);
    return Duel(
      id: 'd1',
      code: 'ABC234',
      kind: kind,
      nameAdjective: 0,
      nameNoun: 0,
      startsAt: startsAt,
      endsAt: startsAt.add(window),
      status: DuelStatus.open,
    );
  }

  setUp(() {
    store = InMemoryEventStore();
    gateway = FakeDuelGateway();
    channel = FakeDuelChannel();
    now = DateTime(2026, 7, 20, 12);
  });

  tearDown(() => channel.close());

  group('scoring', () {
    test('an async duel submits tapped events only', () async {
      final duel = duelOf();
      await store.insert(PuffEvent(
          id: 't1', occurredAt: now, source: EventSource.tap));
      await store.insert(PuffEvent(
          id: 't2', occurredAt: now, source: EventSource.tap));
      await store.insert(PuffEvent(
          id: 'h1', occurredAt: now, source: EventSource.heard));

      await build().submitScore(duel);

      final sent = gateway.submissions.single;
      expect(sent.tapped, 2);
      expect(sent.heard, 0,
          reason: 'a heard event must never score an async duel');
    });

    test('a live duel submits heard events only', () async {
      final duel = duelOf(kind: DuelKind.live, window: const Duration(minutes: 3));
      await store.insert(PuffEvent(
          id: 't1', occurredAt: now, source: EventSource.tap));
      await store.insert(PuffEvent(
          id: 'h1', occurredAt: now, source: EventSource.heard));
      await store.insert(PuffEvent(
          id: 'h2', occurredAt: now, source: EventSource.heard));

      await build().submitScore(duel);

      final sent = gateway.submissions.single;
      expect(sent.heard, 2);
      expect(sent.tapped, 0);
    });

    test('events outside the duel window do not count', () async {
      final duel = duelOf();
      // Comfortably before startsAt (the helper starts a 7-day duel 3.5 days
      // ago), so this is history, not part of the contest.
      await store.insert(PuffEvent(
        id: 'before',
        occurredAt: now.subtract(const Duration(days: 10)),
        source: EventSource.tap,
      ));
      await store.insert(PuffEvent(
          id: 'inside', occurredAt: now, source: EventSource.tap));

      await build().submitScore(duel);
      expect(gateway.submissions.single.tapped, 1);
    });

    test('an ended duel scores only up to its end', () async {
      final duel = Duel(
        id: 'd1',
        code: 'ABC234',
        kind: DuelKind.async,
        nameAdjective: 0,
        nameNoun: 0,
        startsAt: now.subtract(const Duration(days: 8)),
        endsAt: now.subtract(const Duration(days: 1)),
        status: DuelStatus.settled,
      );
      await store.insert(PuffEvent(
        id: 'during',
        occurredAt: now.subtract(const Duration(days: 2)),
        source: EventSource.tap,
      ));
      await store.insert(PuffEvent(
          id: 'after', occurredAt: now, source: EventSource.tap));

      await build().submitScore(duel);
      expect(gateway.submissions.single.tapped, 1);
    });

    test('going offline drops the submission without throwing', () async {
      gateway.offline = true;
      await expectLater(build().submitScore(duelOf()), completes);
      expect(gateway.submissions, isEmpty);
    });
  });

  group('join', () {
    test('a successful join refreshes the list', () async {
      final service = build();
      expect(await service.join('abc234'), isTrue);
      expect(gateway.joined, ['ABC234'], reason: 'codes are upper-cased');
      expect(gateway.listCalls, 1);
    });

    test('the free-tier ceiling is a paywall cue, not a failure', () async {
      gateway.atFreeLimit = true;
      final service = build();

      expect(await service.join('ABC234'), isFalse);
      expect(service.limitReached, isTrue);
    });

    test('a bad code is not a paywall cue', () async {
      gateway.unavailableReason = 'not-found';
      final service = build();

      expect(await service.join('ZZZZZZ'), isFalse);
      expect(service.limitReached, isFalse,
          reason: 'a wrong code must not offer Pro as the fix');
    });
  });

  group('create', () {
    test('a created duel lands at the top of the list', () async {
      final service = build();
      final duel = await service.create(kind: DuelKind.async);

      expect(duel, isNotNull);
      expect(service.duels.first.id, duel!.id);
    });

    test('a free user gets null (RLS refused), not a crash', () async {
      gateway.proBlocked = true;
      expect(await build().create(kind: DuelKind.async), isNull);
    });
  });

  group('live rounds', () {
    test('publishes on the broadcast interval, not per detection', () {
      fakeAsync((async) {
        final service = DuelService(
          gateway,
          store,
          channel: channel,
          clock: () => now,
          broadcastInterval: const Duration(seconds: 2),
        );
        final duel = duelOf(kind: DuelKind.live);
        service.startLive(duel);
        async.flushMicrotasks();

        // Twenty detections in one second must not become twenty messages —
        // the Realtime budget is ~250 concurrent duels at 1 msg/s/client.
        for (var i = 0; i < 20; i++) {
          service.recordLiveDetection();
        }
        async.elapse(const Duration(seconds: 2));

        expect(service.liveCount, 20);
        expect(channel.published.length, 1);
        expect(channel.published.single.count, 20);
      });
    });

    test('an opponent score arrives and is tracked', () async {
      final service = build();
      await service.startLive(duelOf(kind: DuelKind.live));

      channel.emitOpponent('rival', 5);
      await Future<void>.delayed(Duration.zero);

      expect(service.liveOpponents['rival'], 5);
    });

    test('stopping a round releases the channel and timer', () {
      fakeAsync((async) {
        final service = build();
        service.startLive(duelOf(kind: DuelKind.live));
        async.flushMicrotasks();

        service.stopLive();
        async.flushMicrotasks();
        channel.published.clear();
        async.elapse(const Duration(seconds: 10));

        expect(channel.left, isTrue);
        expect(channel.published, isEmpty,
            reason: 'no broadcasts after the round ends');
      });
    });
  });

  group('refresh', () {
    test('offline keeps the last list instead of emptying the tab', () async {
      final service = build();
      await service.create(kind: DuelKind.async);
      await service.refresh();
      expect(service.duels, isNotEmpty);

      gateway.offline = true;
      await service.refresh();
      expect(service.duels, isNotEmpty);
    });
  });
}
