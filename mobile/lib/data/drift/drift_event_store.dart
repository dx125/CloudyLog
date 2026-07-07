import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/puff_event.dart';
import '../event_store.dart';
import 'puff_database.dart';

class DriftEventStore implements EventStore {
  DriftEventStore(this._db);

  final PuffDatabase _db;

  @override
  Future<void> insert(PuffEvent event) async {
    await _db.into(_db.events).insert(_toRow(event, synced: false));
  }

  @override
  Future<void> upsertAll(List<PuffEvent> events, {required bool synced}) async {
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(
        _db.events,
        [for (final e in events) _toRow(e, synced: synced)],
      );
    });
  }

  @override
  Future<void> updateTags(String id, List<String> tags) async {
    await (_db.update(_db.events)..where((t) => t.id.equals(id))).write(
      EventsCompanion(
        tags: Value(jsonEncode(tags)),
        syncedAt: const Value(null),
      ),
    );
  }

  @override
  Future<PuffEvent?> byId(String id) async {
    final row = await (_db.select(_db.events)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<int> countForDay(DateTime day) async {
    final start = dayOf(day);
    final end = start.add(const Duration(days: 1));
    final countExp = _db.events.id.count();
    final query = _db.selectOnly(_db.events)
      ..addColumns([countExp])
      ..where(_db.events.type.equals(kTootType) &
          _db.events.occurredAt.isBiggerOrEqualValue(start) &
          _db.events.occurredAt.isSmallerThanValue(end));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  @override
  Future<List<PuffEvent>> eventsBetween(DateTime from, DateTime to) async {
    final rows = await (_db.select(_db.events)
          ..where((t) =>
              t.occurredAt.isBiggerOrEqualValue(from) &
              t.occurredAt.isSmallerThanValue(to))
          ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<PuffEvent>> allEvents() async {
    final rows = await (_db.select(_db.events)
          ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<PuffEvent>> unsynced(int limit) async {
    final rows = await (_db.select(_db.events)
          ..where((t) => t.syncedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)])
          ..limit(limit))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> markSynced(List<String> ids, DateTime at) async {
    if (ids.isEmpty) return;
    await (_db.update(_db.events)..where((t) => t.id.isIn(ids)))
        .write(EventsCompanion(syncedAt: Value(at)));
  }

  @override
  Future<Map<DateTime, int>> countsByDay() async {
    // Pilot scale: group in Dart so "day" is unambiguously the device-local
    // day, matching everything the user sees.
    final rows = await (_db.selectOnly(_db.events)
          ..addColumns([_db.events.occurredAt])
          ..where(_db.events.type.equals(kTootType)))
        .get();
    final counts = <DateTime, int>{};
    for (final row in rows) {
      final day = dayOf(row.read(_db.events.occurredAt)!);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts;
  }

  EventsCompanion _toRow(PuffEvent e, {required bool synced}) =>
      EventsCompanion.insert(
        id: e.id,
        type: Value(e.type),
        occurredAt: e.occurredAt,
        tags: Value(jsonEncode(e.tags)),
        deviceId: Value(e.deviceId),
        syncedAt: Value(synced ? DateTime.now() : e.syncedAt),
      );

  PuffEvent _toDomain(Event row) => PuffEvent(
        id: row.id,
        type: row.type,
        occurredAt: row.occurredAt,
        tags: (jsonDecode(row.tags) as List<dynamic>).cast<String>(),
        deviceId: row.deviceId,
        syncedAt: row.syncedAt,
      );
}
