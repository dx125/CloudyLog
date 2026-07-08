import 'package:flutter_test/flutter_test.dart';
import 'package:puff/data/diagnostics_store.dart';
import 'package:puff/services/diagnostics_service.dart';

import 'fakes.dart';

void main() {
  final now = DateTime(2026, 7, 8, 9, 0);

  late InMemoryDiagnosticsStore store;
  late DiagnosticsService service;

  setUp(() {
    store = InMemoryDiagnosticsStore();
    service = DiagnosticsService(store, clock: () => now, ringSize: 3);
  });

  test('record keeps the entry in the ring and persists it', () async {
    service.record('sync.push', StateError('boom'),
        StackTrace.fromString('#0 somewhere'));

    expect(service.entries.single.source, 'sync.push');
    expect(service.entries.single.message, contains('boom'));
    expect(service.entries.single.stack, '#0 somewhere');
    expect(service.totalCount, 1);

    expect(await service.fullText(), contains('boom'));
    expect(store.entries, hasLength(1));
  });

  test('ring keeps the newest entries; the store keeps everything', () async {
    for (var i = 0; i < 5; i++) {
      service.record('source', 'error $i');
    }

    expect(service.totalCount, 5);
    expect(service.entries, hasLength(3));
    expect(service.entries.first.message, 'error 2');
    expect(service.entries.last.message, 'error 4');

    await service.fullText(); // drains the write queue
    expect(store.entries, hasLength(5));
  });

  test('load restores history from the store, newest first in the ring',
      () async {
    for (var i = 0; i < 4; i++) {
      store.entries.add(DiagnosticsEntry(
        time: now,
        source: 'previous.run',
        message: 'old $i',
      ));
    }

    await service.load();

    expect(service.totalCount, 4);
    expect(service.entries, hasLength(3));
    expect(service.entries.last.message, 'old 3');
  });

  test('clear empties the ring and the store', () async {
    service.record('source', 'error');
    await service.clear();

    expect(service.entries, isEmpty);
    expect(service.totalCount, 0);
    expect(store.entries, isEmpty);
  });

  test('long stacks are truncated to the cap', () {
    final capped = DiagnosticsService(store, clock: () => now,
        maxStackChars: 10);

    capped.record('source', 'error', StackTrace.fromString('x' * 100));

    expect(capped.entries.single.stack.length, 10);
  });

  test('a listener that records does not recurse', () {
    service.addListener(() {
      service.record('listener', 'echo'); // must be dropped, not loop
    });

    service.record('source', 'original');

    expect(service.totalCount, 1);
    expect(service.entries.single.message, 'original');
  });
}
