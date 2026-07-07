import 'package:flutter_test/flutter_test.dart';
import 'package:puff/domain/puff_event.dart';
import 'package:puff/services/sync_service.dart';

import 'fakes.dart';

void main() {
  group('SyncService', () {
    late InMemoryEventStore store;
    late FakeEventsSyncGateway gateway;
    late bool proAndSignedIn;
    late SyncService service;

    setUp(() {
      store = InMemoryEventStore();
      gateway = FakeEventsSyncGateway();
      proAndSignedIn = true;
      service = SyncService(
        store,
        gateway,
        shouldSync: () => proAndSignedIn,
        debounce: Duration.zero,
      );
    });

    tearDown(() => service.dispose());

    PuffEvent event(String id, {DateTime? at}) =>
        PuffEvent(id: id, occurredAt: at ?? DateTime(2026, 7, 7, 9));

    test('pushes unsynced events and marks them synced', () async {
      await store.insert(event('a'));
      await store.insert(event('b'));

      expect(await service.pushPending(), isTrue);
      expect(gateway.server.keys, containsAll(['a', 'b']));
      expect((await store.unsynced(10)), isEmpty);
    });

    test('does nothing for free users', () async {
      proAndSignedIn = false;
      await store.insert(event('a'));
      expect(await service.pushPending(), isFalse);
      expect(gateway.server, isEmpty);
    });

    test('offline push fails without losing anything', () async {
      gateway.offline = true;
      await store.insert(event('a'));
      expect(await service.pushPending(), isFalse);
      expect((await store.unsynced(10)).length, 1);
    });

    test('a tag edit clears synced state and is pushed again', () async {
      await store.insert(event('a'));
      await service.pushPending();
      expect((await store.unsynced(10)), isEmpty);

      await store.updateTags('a', ['thunder']);
      expect((await store.unsynced(10)).length, 1);

      await service.pushPending();
      expect(gateway.server['a']!.tags, ['thunder']);
    });

    test('restore merges cloud events into the local store', () async {
      await store.insert(event('local'));
      gateway.server['remote'] = event('remote');

      expect(await service.restoreFromCloud(), isTrue);
      expect(store.events.keys, containsAll(['local', 'remote']));
      // Restored events are already synced; local unsynced one remains.
      expect((await store.unsynced(10)).map((e) => e.id), ['local']);
    });

    test('push is idempotent across retries', () async {
      await store.insert(event('a'));
      await service.pushPending();
      await store.updateTags('a', ['sbd']);
      await service.pushPending();
      expect(gateway.server.length, 1);
      expect(gateway.pushCalls, 2);
    });
  });
}
