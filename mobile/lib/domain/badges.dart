/// Everything a badge predicate may look at, derived from the event log.
class BadgeFacts {
  const BadgeFacts({
    required this.totalCount,
    required this.bestDayCount,
    required this.longestStreak,
    required this.daysLogged,
    required this.distinctClassicTagsUsed,
  });

  final int totalCount;
  final int bestDayCount;
  final int longestStreak;
  final int daysLogged;
  final int distinctClassicTagsUsed;
}

class BadgeSpec {
  const BadgeSpec({
    required this.id,
    required this.emoji,
    required this.inBasicSet,
    required this.earned,
  });

  final String id;
  final String emoji;

  /// Basic badges ship free; the rest are the Pro "full badge collection".
  final bool inBasicSet;
  final bool Function(BadgeFacts) earned;
}

/// The launch collection. Names and descriptions live in the ARB, keyed by id.
const List<BadgeSpec> kBadges = [
  BadgeSpec(
    id: 'first_puff',
    emoji: '🌬️',
    inBasicSet: true,
    earned: _firstPuff,
  ),
  BadgeSpec(
    id: 'double_digits',
    emoji: '🔟',
    inBasicSet: true,
    earned: _doubleDigits,
  ),
  BadgeSpec(id: 'streak_3', emoji: '🌤️', inBasicSet: true, earned: _streak3),
  BadgeSpec(id: 'streak_7', emoji: '🌀', inBasicSet: true, earned: _streak7),
  BadgeSpec(id: 'streak_30', emoji: '🌊', inBasicSet: false, earned: _streak30),
  BadgeSpec(id: 'century', emoji: '💯', inBasicSet: false, earned: _century),
  BadgeSpec(
    id: 'gale_force',
    emoji: '💨',
    inBasicSet: false,
    earned: _galeForce,
  ),
  BadgeSpec(
    id: 'tag_collector',
    emoji: '🎩',
    inBasicSet: false,
    earned: _tagCollector,
  ),
  BadgeSpec(id: 'regular', emoji: '📅', inBasicSet: false, earned: _regular),
];

bool _firstPuff(BadgeFacts f) => f.totalCount >= 1;
bool _doubleDigits(BadgeFacts f) => f.bestDayCount >= 10;
bool _streak3(BadgeFacts f) => f.longestStreak >= 3;
bool _streak7(BadgeFacts f) => f.longestStreak >= 7;
bool _streak30(BadgeFacts f) => f.longestStreak >= 30;
bool _century(BadgeFacts f) => f.totalCount >= 100;
bool _galeForce(BadgeFacts f) => f.bestDayCount >= 20;
bool _tagCollector(BadgeFacts f) => f.distinctClassicTagsUsed >= 4;
bool _regular(BadgeFacts f) => f.daysLogged >= 14;
