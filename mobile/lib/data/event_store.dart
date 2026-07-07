import '../domain/puff_event.dart';

/// The on-device append-only event log — the source of truth for everything.
/// Concrete impl is Drift/SQLite; tests use an in-memory fake.
abstract class EventStore {
  Future<void> insert(PuffEvent event);

  /// Restore path: merge cloud events in by id (existing rows win nothing —
  /// same id means same immutable event; tags take the incoming value).
  Future<void> upsertAll(List<PuffEvent> events, {required bool synced});

  /// Quick-tag edits. Clears synced_at so the change is pushed again.
  Future<void> updateTags(String id, List<String> tags);

  Future<PuffEvent?> byId(String id);
  Future<int> countForDay(DateTime day);
  Future<List<PuffEvent>> eventsBetween(DateTime from, DateTime to);
  Future<List<PuffEvent>> allEvents();
  Future<List<PuffEvent>> unsynced(int limit);
  Future<void> markSynced(List<String> ids, DateTime at);

  /// Counts per local day over the whole log (charts, streaks, badges).
  Future<Map<DateTime, int>> countsByDay();
}
