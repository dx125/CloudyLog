// Duels — head-to-head weeks (async) and live rounds (live).
//
// Pure Dart: no plugins, no network. The wire shape is deliberately thin
// because the server holds indices, not words (see [duelAdjectives]).

/// How a duel is scored, and how much it's worth taking seriously.
enum DuelKind {
  /// Tap-scored, a week long. The real competition — tapped events are the
  /// trustworthy log, so this is what carries the leaderboard's weight.
  async,

  /// Heard-scored, minutes long, both phones in Listen mode.
  ///
  /// **Honour-system party mode by design.** A mouth raspberry defeats any
  /// classifier we can ship, so the anti-cheat here is social: you're in the
  /// same room and people are watching. Never present a live result as
  /// verified — the product would be claiming something it can't deliver.
  live;

  String get wire => name;

  static DuelKind fromWire(String? raw) =>
      raw == 'live' ? DuelKind.live : DuelKind.async;
}

enum DuelStatus {
  open,
  running,
  settled;

  static DuelStatus fromWire(String? raw) => switch (raw) {
        'running' => DuelStatus.running,
        'settled' => DuelStatus.settled,
        _ => DuelStatus.open,
      };
}

/// Curated name vocabulary.
///
/// Duel names and player handles are **indices into these lists**, never
/// user-typed strings. TODO.md lists a profanity filter and a report flow as a
/// hard blocker before any social feature ships; this deletes that blocker
/// instead of mitigating it. There is no column a slur can go in, so there's no
/// filter to bypass, no moderation queue, and no store-review exposure — and
/// "Breezy Badgers" is funnier than what people would type anyway.
///
/// Air and wind only, per the brand world. No brown, ever.
///
/// **These lists are append-only.** Reordering or removing an entry silently
/// renames every existing duel, because the server stored a position, not a
/// word. Add to the end; keep the counts in sync with `functions/duels/index.ts`.
const List<String> duelAdjectives = [
  'Breezy', 'Gusty', 'Silent', 'Thunderous', 'Whispering', 'Drafty',
  'Blustery', 'Swirling', 'Restless', 'Sudden', 'Rolling', 'Howling',
  'Gentle', 'Brisk', 'Wandering', 'Fluffy', 'Lofty', 'Puffy',
  'Squeaky', 'Rumbling', 'Airy', 'Hasty', 'Muffled', 'Chipper',
];

const List<String> duelNouns = [
  'Badgers', 'Storms', 'Gales', 'Whirlwinds', 'Zephyrs', 'Drafts',
  'Squalls', 'Currents', 'Breezes', 'Cyclones', 'Gusts', 'Puffs',
  'Clouds', 'Eddies', 'Vapours', 'Ferrets', 'Otters', 'Beavers',
  'Bellows', 'Balloons', 'Kites', 'Whistles', 'Trumpets', 'Sirens',
];

/// Player handles inside a duel. Single words so a scoreboard row stays short.
const List<String> duelHandles = [
  'Zephyr', 'Squall', 'Draft', 'Breeze', 'Gale', 'Gust',
  'Cyclone', 'Whirl', 'Whisper', 'Rumble', 'Puff', 'Cloud',
  'Eddy', 'Current', 'Vapour', 'Bellow', 'Balloon', 'Kite',
  'Whistle', 'Trumpet', 'Siren', 'Drift', 'Swirl', 'Flurry',
];

/// Renders a duel's name from its stored indices.
///
/// Wraps rather than throwing: an index from a newer server build must degrade
/// to a slightly-wrong name, never to a crash on the Duels tab.
String duelName(int adjective, int noun) =>
    '${duelAdjectives[adjective % duelAdjectives.length]} '
    '${duelNouns[noun % duelNouns.length]}';

String duelHandle(int handle) => duelHandles[handle % duelHandles.length];

/// One participant's standing in a duel.
class DuelScore {
  const DuelScore({
    required this.userId,
    required this.handle,
    this.tapped = 0,
    this.heard = 0,
  });

  final String userId;
  final int handle;

  /// Tapped events in the duel window — what an [DuelKind.async] duel scores.
  final int tapped;

  /// Heard events — what a [DuelKind.live] duel scores. Never summed with
  /// [tapped]: they mean different things and mixing them would launder a
  /// guess into the health-grade number.
  final int heard;

  int pointsFor(DuelKind kind) =>
      kind == DuelKind.live ? heard : tapped;

  String get name => duelHandle(handle);
}

class Duel {
  const Duel({
    required this.id,
    required this.code,
    required this.kind,
    required this.nameAdjective,
    required this.nameNoun,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.createdBy = '',
    this.scores = const [],
  });

  final String id;

  /// Six characters from an unambiguous alphabet — shared as plain text over
  /// any chat app, which is why duels need no deep-link infrastructure.
  final String code;

  final DuelKind kind;
  final int nameAdjective;
  final int nameNoun;
  final DateTime startsAt;
  final DateTime endsAt;
  final DuelStatus status;
  final String createdBy;
  final List<DuelScore> scores;

  String get name => duelName(nameAdjective, nameNoun);

  bool isOver(DateTime now) => !now.isBefore(endsAt);

  Duration remaining(DateTime now) {
    final left = endsAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Scores highest-first. Ties keep their incoming order, so a scoreboard
  /// doesn't jitter between refreshes.
  List<DuelScore> get standings {
    final sorted = [...scores];
    sorted.sort((a, b) => b.pointsFor(kind).compareTo(a.pointsFor(kind)));
    return sorted;
  }

  /// The single leader, or null when nobody is ahead — including the all-zero
  /// start, where declaring a "winner" would be nonsense.
  DuelScore? get leader {
    final ranked = standings;
    if (ranked.isEmpty) return null;
    final top = ranked.first.pointsFor(kind);
    if (top == 0) return null;
    if (ranked.length > 1 && ranked[1].pointsFor(kind) == top) return null;
    return ranked.first;
  }

  factory Duel.fromJson(Map<String, Object?> json) {
    final members = <String, int>{
      for (final m in (json['duel_members'] as List<dynamic>? ?? const []))
        (m as Map<String, Object?>)['user_id'] as String:
            (m['handle'] as num?)?.toInt() ?? 0,
    };
    final scoreRows =
        (json['duel_scores'] as List<dynamic>? ?? const []).cast<Map<String, Object?>>();

    final scores = <DuelScore>[
      for (final entry in members.entries)
        () {
          final row = scoreRows.cast<Map<String, Object?>?>().firstWhere(
                (r) => r?['user_id'] == entry.key,
                orElse: () => null,
              );
          return DuelScore(
            userId: entry.key,
            handle: entry.value,
            tapped: (row?['tapped'] as num?)?.toInt() ?? 0,
            heard: (row?['heard'] as num?)?.toInt() ?? 0,
          );
        }(),
    ];

    return Duel(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      kind: DuelKind.fromWire(json['kind'] as String?),
      nameAdjective: (json['name_adj'] as num?)?.toInt() ?? 0,
      nameNoun: (json['name_noun'] as num?)?.toInt() ?? 0,
      startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
      endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
      status: DuelStatus.fromWire(json['status'] as String?),
      createdBy: json['created_by'] as String? ?? '',
      scores: scores,
    );
  }
}
