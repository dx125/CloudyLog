import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'puff_database.g.dart';

/// The append-only events table (handoff §7): never update counts in place;
/// derive everything from events. `tags` is a JSON-encoded string list.
class Events extends Table {
  TextColumn get id => text()();
  TextColumn get type => text().withDefault(const Constant('toot'))();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  TextColumn get deviceId => text().withDefault(const Constant(''))();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Events])
class PuffDatabase extends _$PuffDatabase {
  PuffDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

QueryExecutor openPuffDatabase() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    return NativeDatabase.createInBackground(
      File(p.join(dir.path, 'puff.db')),
    );
  });
}
