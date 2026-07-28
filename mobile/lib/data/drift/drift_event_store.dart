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
  Future<void> delete(String id) async {
    await (_db.delete(_db.events)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<PuffEvent?> byId(String id) async {
    final row = await (_db.select(_db.events)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<int> countForDay(
    DateTime day, {
    SourceFilter source = SourceFilter.tapped,
  }) async {
    final start = dayOf(day);
    final end = start.add(const Duration(days: 1));
    final countExp = _db.events.id.count();
    final query = _db.selectOnly(_db.events)
      ..addColumns([countExp])
      ..where(_db.events.type.equals(kTootType) &
          _sourceWhere(source) &
          _db.events.occurredAt.isBiggerOrEqualValue(start) &
          _db.events.occurredAt.isSmallerThanValue(end));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  @override
  Future<List<PuffEvent>> eventsBetween(
    DateTime from,
    DateTime to, {
    SourceFilter source = SourceFilter.all,
  }) async {
    final rows = await (_db.select(_db.events)
          ..where((t) =>
              t.occurredAt.isBiggerOrEqualValue(from) &
              t.occurredAt.isSmallerThanValue(to) &
              _sourceWhere(source))
          ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<PuffEvent>> allEvents({
    SourceFilter source = SourceFilter.all,
  }) async {
    final rows = await (_db.select(_db.events)
          ..where((t) => _sourceWhere(source))
          ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  /// SQL for a [SourceFilter]. `all` becomes a constant-true term so callers
  /// can always `&` it in without branching.
  Expression<bool> _sourceWhere(SourceFilter filter) => switch (filter) {
        SourceFilter.tapped => _db.events.source.equals(kSourceTap),
        SourceFilter.heard => _db.events.source.equals(kSourceHeard),
        SourceFilter.all => const Constant(true),
      };

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
  Future<Map<DateTime, int>> countsByDay({
    SourceFilter source = SourceFilter.tapped,
  }) async {
    // Pilot scale: group in Dart so "day" is unambiguously the device-local
    // day, matching everything the user sees.
    final rows = await (_db.selectOnly(_db.events)
          ..addColumns([_db.events.occurredAt])
          ..where(_db.events.type.equals(kTootType) & _sourceWhere(source)))
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
        source: Value(sourceName(e.source)),
        syncedAt: Value(synced ? DateTime.now() : e.syncedAt),
      );

  PuffEvent _toDomain(Event row) => PuffEvent(
        id: row.id,
        type: row.type,
        occurredAt: row.occurredAt,
        tags: (jsonDecode(row.tags) as List<dynamic>).cast<String>(),
        deviceId: row.deviceId,
        source: sourceFrom(row.source),
        syncedAt: row.syncedAt,
      );
}
