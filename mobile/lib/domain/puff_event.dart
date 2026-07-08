/// One logged moment. The append-only event log is the whole data model:
/// counts, streaks, badges, charts and Wrapped are all derived from events —
/// never stored counters. Meals become a second [type] when the trigger food
/// detective ships (Phase 2).
class PuffEvent {
  const PuffEvent({
    required this.id,
    required this.occurredAt,
    this.type = kTootType,
    this.tags = const [],
    this.deviceId = '',
    this.syncedAt,
  });

  /// Client-generated UUIDv7 — time-ordered, and the idempotency key for sync.
  final String id;
  final DateTime occurredAt;
  final String type;
  final List<String> tags;
  final String deviceId;

  /// Null while the event hasn't been pushed to the cloud. Editing tags
  /// clears it so the edit is pushed again (upsert, last-write-wins).
  final DateTime? syncedAt;

  PuffEvent copyWith({List<String>? tags, DateTime? syncedAt}) => PuffEvent(
        id: id,
        occurredAt: occurredAt,
        type: type,
        tags: tags ?? this.tags,
        deviceId: deviceId,
        syncedAt: syncedAt,
      );
}

const String kTootType = 'toot';

/// The four classic quick tags — the free tier's whole set.
const List<String> kClassicTags = ['silent', 'squeaky', 'thunder', 'sbd'];

/// Extra built-in tags in the Pro "full set" (custom tags come on top).
const List<String> kProTags = ['windy', 'oops'];

/// Quick tags apply to the last log for this long, then reset (Design Book §07).
const Duration kQuickTagWindow = Duration(seconds: 10);

DateTime dayOf(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

/// Canonical 'YYYY-MM-DD' key for a local day — prefs markers and the wire
/// format of stat reports.
String dayKey(DateTime day) => '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';
