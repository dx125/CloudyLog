import 'package:flutter_test/flutter_test.dart';
import 'package:puff/domain/badges.dart';
import 'package:puff/domain/percentile.dart';
import 'package:puff/domain/streaks.dart';

void main() {
  group('streaks', () {
    final today = DateTime(2026, 7, 7);
    DateTime day(int daysAgo) => today.subtract(Duration(days: daysAgo));

    test('empty history has no streak', () {
      expect(currentStreak({}, today), 0);
    });

    test('counts consecutive days ending today', () {
      expect(currentStreak({day(0), day(1), day(2)}, today), 3);
    });

    test('an empty today does not break the streak yet', () {
      expect(currentStreak({day(1), day(2)}, today), 2);
    });

    test('a gap resets the streak', () {
      expect(currentStreak({day(0), day(2), day(3)}, today), 1);
    });

    test('longestStreak finds a historical run', () {
      final days = {day(0), day(10), day(11), day(12), day(13)};
      expect(longestStreak(days), 4);
    });
  });

  group('percentileRankFor', () {
    test('empty distribution scores 0', () {
      expect(percentileRankFor(10, {}), 0);
    });

    test('strict top scores near 100', () {
      expect(percentileRankFor(50, {'10': 5, '20': 5, '50': 1}), 95);
    });

    test('all tied lands at the midpoint', () {
      expect(percentileRankFor(35, {'35': 100}), 50);
    });

    test('mixed distribution', () {
      // 4 below, 4 equal (half counts), total 10 → 60.
      expect(percentileRankFor(10, {'0': 4, '10': 4, '20': 2}), 60);
    });
  });

  group('worldPaceFor', () {
    test('maps counts onto the healthy range', () {
      expect(worldPaceFor(0), WorldPace.quiet);
      expect(worldPaceFor(9), WorldPace.quiet);
      expect(worldPaceFor(10), WorldPace.onPace);
      expect(worldPaceFor(20), WorldPace.onPace);
      expect(worldPaceFor(21), WorldPace.breezy);
    });
  });

  group('badges', () {
    BadgeFacts facts({
      int total = 0,
      int bestDay = 0,
      int streak = 0,
      int days = 0,
      int tags = 0,
    }) =>
        BadgeFacts(
          totalCount: total,
          bestDayCount: bestDay,
          longestStreak: streak,
          daysLogged: days,
          distinctClassicTagsUsed: tags,
        );

    Set<String> earnedIds(BadgeFacts f) =>
        {for (final b in kBadges.where((b) => b.earned(f))) b.id};

    test('nothing earned on a fresh install', () {
      expect(earnedIds(facts()), isEmpty);
    });

    test('first tap earns first_puff only', () {
      expect(earnedIds(facts(total: 1, bestDay: 1, streak: 1, days: 1)),
          {'first_puff'});
    });

    test('a heavy day earns count badges', () {
      final ids = earnedIds(facts(total: 25, bestDay: 25, streak: 1, days: 1));
      expect(ids, containsAll(['double_digits', 'gale_force']));
      expect(ids, isNot(contains('century')));
    });

    test('streak badges ladder up', () {
      final ids = earnedIds(facts(total: 40, bestDay: 5, streak: 30, days: 30));
      expect(ids, containsAll(['streak_3', 'streak_7', 'streak_30', 'regular']));
    });

    test('tag_collector needs all four classic tags', () {
      expect(earnedIds(facts(total: 5, tags: 3)),
          isNot(contains('tag_collector')));
      expect(earnedIds(facts(total: 5, tags: 4)), contains('tag_collector'));
    });

    test('basic set is exactly the free badges', () {
      final basic = kBadges.where((b) => b.inBasicSet).map((b) => b.id);
      expect(basic,
          containsAll(['first_puff', 'double_digits', 'streak_3', 'streak_7']));
      expect(basic.length, 4);
    });
  });
}
