import '../domain/puff_event.dart';

/// Which events a query counts.
///
/// Defaults are deliberately [tapped] everywhere health numbers are derived:
/// heard events are real logs but not trustworthy health data, and a caller
/// that forgets to think about the distinction should get the conservative
/// answer rather than silently contaminate streaks, badges or world stats.
enum SourceFilter {
  tapped,
  heard,
  all;

  bool matches(EventSource source) => switch (this) {
        SourceFilter.tapped => source == EventSource.tap,
        SourceFilter.heard => source == EventSource.heard,
        SourceFilter.all => true,
      };
}

/// The on-device append-only event log — the source of truth for everything.
/// Concrete impl is Drift/SQLite; tests use an in-memory fake.
abstract class EventStore {
  Future<void> insert(PuffEvent event);

  /// Restore path: merge cloud events in by id (existing rows win nothing —
  /// same id means same immutable event; tags take the incoming value).
  Future<void> upsertAll(List<PuffEvent> events, {required bool synced});

  /// Quick-tag edits. Clears synced_at so the change is pushed again.
  Future<void> updateTags(String id, List<String> tags);

  /// Removes one event outright. Only Listen mode's undo uses this — tapped
  /// events are never deleted, and an undone detection must leave no trace.
  Future<void> delete(String id);

  Future<PuffEvent?> byId(String id);

  Future<int> countForDay(
    DateTime day, {
    SourceFilter source = SourceFilter.tapped,
  });

  Future<List<PuffEvent>> eventsBetween(
    DateTime from,
    DateTime to, {
    SourceFilter source = SourceFilter.all,
  });

  Future<List<PuffEvent>> allEvents({SourceFilter source = SourceFilter.all});
  Future<List<PuffEvent>> unsynced(int limit);
  Future<void> markSynced(List<String> ids, DateTime at);

  /// Counts per local day over the whole log (charts, streaks, badges).
  Future<Map<DateTime, int>> countsByDay({
    SourceFilter source = SourceFilter.tapped,
  });
}
