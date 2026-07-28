import 'package:flutter_test/flutter_test.dart';
import 'package:puff/domain/duel.dart';

void main() {
  final now = DateTime(2026, 7, 20, 12);

  Duel duel({
    DuelKind kind = DuelKind.async,
    List<DuelScore> scores = const [],
    DateTime? endsAt,
  }) =>
      Duel(
        id: 'd1',
        code: 'BREEZY',
        kind: kind,
        nameAdjective: 0,
        nameNoun: 0,
        startsAt: now.subtract(const Duration(days: 1)),
        endsAt: endsAt ?? now.add(const Duration(days: 6)),
        status: DuelStatus.open,
        scores: scores,
      );

  group('curated names', () {
    test('renders a name from indices', () {
      expect(duelName(0, 0), 'Breezy Badgers');
    });

    test('every index pair yields a non-empty two-word name', () {
      for (var a = 0; a < duelAdjectives.length; a++) {
        for (var n = 0; n < duelNouns.length; n++) {
          final name = duelName(a, n);
          expect(name.split(' ').length, 2, reason: 'bad name: $name');
          expect(name.trim(), isNotEmpty);
        }
      }
    });

    // The server may hold an index this build doesn't know (newer vocabulary).
    // Degrading to a slightly-wrong name beats crashing the Duels tab.
    test('out-of-range indices wrap instead of throwing', () {
      expect(() => duelName(9999, 9999), returnsNormally);
      expect(() => duelHandle(9999), returnsNormally);
      expect(duelName(duelAdjectives.length, duelNouns.length),
          duelName(0, 0));
    });

    test('negative indices do not throw', () {
      expect(() => duelName(-1, -1), returnsNormally);
      expect(() => duelHandle(-5), returnsNormally);
    });

    test('the vocabulary stays on-brand — no brown, ever', () {
      const banned = ['brown', 'poo', 'poop', 'crap', 'shit', 'turd'];
      for (final word in [...duelAdjectives, ...duelNouns, ...duelHandles]) {
        for (final bad in banned) {
          expect(word.toLowerCase(), isNot(contains(bad)),
              reason: '$word breaks the brand rule');
        }
      }
    });

    test('vocabulary entries are unique', () {
      expect(duelAdjectives.toSet().length, duelAdjectives.length);
      expect(duelNouns.toSet().length, duelNouns.length);
      expect(duelHandles.toSet().length, duelHandles.length);
    });

    // The server stores positions, so these counts are part of the wire
    // contract with functions/duels/index.ts.
    test('vocabulary counts match the server constants', () {
      expect(duelAdjectives.length, 24);
      expect(duelNouns.length, 24);
      expect(duelHandles.length, 24);
    });
  });

  group('scoring', () {
    test('an async duel scores taps, a live duel scores heard', () {
      const score = DuelScore(userId: 'u', handle: 0, tapped: 7, heard: 3);
      expect(score.pointsFor(DuelKind.async), 7);
      expect(score.pointsFor(DuelKind.live), 3);
    });

    test('standings rank highest first', () {
      final d = duel(scores: const [
        DuelScore(userId: 'a', handle: 0, tapped: 3),
        DuelScore(userId: 'b', handle: 1, tapped: 9),
        DuelScore(userId: 'c', handle: 2, tapped: 5),
      ]);
      expect(d.standings.map((s) => s.userId), ['b', 'c', 'a']);
    });

    test('a live duel ranks by heard, not tapped', () {
      final d = duel(kind: DuelKind.live, scores: const [
        DuelScore(userId: 'a', handle: 0, tapped: 100, heard: 1),
        DuelScore(userId: 'b', handle: 1, tapped: 0, heard: 4),
      ]);
      expect(d.standings.first.userId, 'b',
          reason: 'tapped events must not win a live round');
    });

    test('nobody leads an all-zero duel', () {
      final d = duel(scores: const [
        DuelScore(userId: 'a', handle: 0),
        DuelScore(userId: 'b', handle: 1),
      ]);
      expect(d.leader, isNull);
    });

    test('a tie has no leader', () {
      final d = duel(scores: const [
        DuelScore(userId: 'a', handle: 0, tapped: 4),
        DuelScore(userId: 'b', handle: 1, tapped: 4),
      ]);
      expect(d.leader, isNull);
    });

    test('a clear lead has a leader', () {
      final d = duel(scores: const [
        DuelScore(userId: 'a', handle: 0, tapped: 6),
        DuelScore(userId: 'b', handle: 1, tapped: 4),
      ]);
      expect(d.leader!.userId, 'a');
    });
  });

  group('timing', () {
    test('remaining never goes negative', () {
      final d = duel(endsAt: now.subtract(const Duration(hours: 1)));
      expect(d.remaining(now), Duration.zero);
      expect(d.isOver(now), isTrue);
    });

    test('an open duel reports time left', () {
      final d = duel(endsAt: now.add(const Duration(hours: 5)));
      expect(d.remaining(now), const Duration(hours: 5));
      expect(d.isOver(now), isFalse);
    });
  });

  group('fromJson', () {
    test('joins members to their scores', () {
      final d = Duel.fromJson({
        'id': 'd1',
        'code': 'ABC234',
        'kind': 'async',
        'name_adj': 1,
        'name_noun': 2,
        'starts_at': '2026-07-19T12:00:00Z',
        'ends_at': '2026-07-26T12:00:00Z',
        'status': 'open',
        'created_by': 'u1',
        'duel_members': [
          {'user_id': 'u1', 'handle': 3},
          {'user_id': 'u2', 'handle': 4},
        ],
        'duel_scores': [
          {'user_id': 'u1', 'tapped': 12, 'heard': 0},
        ],
      });

      expect(d.scores.length, 2);
      final u1 = d.scores.firstWhere((s) => s.userId == 'u1');
      final u2 = d.scores.firstWhere((s) => s.userId == 'u2');
      expect(u1.tapped, 12);
      expect(u2.tapped, 0, reason: 'a member with no score row sits at zero');
      expect(u2.handle, 4);
    });

    test('survives missing optional fields', () {
      final d = Duel.fromJson({
        'id': 'd1',
        'kind': 'live',
        'starts_at': '2026-07-19T12:00:00Z',
        'ends_at': '2026-07-19T12:03:00Z',
      });
      expect(d.kind, DuelKind.live);
      expect(d.scores, isEmpty);
      expect(d.code, '');
      expect(d.status, DuelStatus.open);
    });

    test('an unknown kind falls back to async', () {
      expect(DuelKind.fromWire('something-else'), DuelKind.async);
      expect(DuelKind.fromWire(null), DuelKind.async);
    });
  });
}
