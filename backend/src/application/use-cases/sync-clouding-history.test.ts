import { describe, expect, test } from 'vitest';

import { InMemoryCloudingRepository } from './fakes.test-helpers';
import {
  InvalidHistoryPayload,
  SyncCloudingHistory,
} from './sync-clouding-history';

describe('SyncCloudingHistory', () => {
  test('uploads local history and returns the merged server view', async () => {
    const repo = new InMemoryCloudingRepository();
    const sync = new SyncCloudingHistory(repo);

    const merged = await sync.execute('u1', [
      { day: '2026-07-01', count: 10 },
      { day: '2026-07-02', count: 35 },
    ]);

    expect(merged).toHaveLength(2);
    expect((await repo.getForDay('u1', '2026-07-02'))?.count).toBe(35);
  });

  test('per-day merge keeps the larger count in either direction', async () => {
    const repo = new InMemoryCloudingRepository();
    await repo.setForDay('u1', '2026-07-01', 20); // server ahead
    await repo.setForDay('u1', '2026-07-02', 5); // device ahead
    const sync = new SyncCloudingHistory(repo);

    await sync.execute('u1', [
      { day: '2026-07-01', count: 10 },
      { day: '2026-07-02', count: 30 },
    ]);

    expect((await repo.getForDay('u1', '2026-07-01'))?.count).toBe(20);
    expect((await repo.getForDay('u1', '2026-07-02'))?.count).toBe(30);
  });

  test('zero-count entries do not create server rows', async () => {
    const repo = new InMemoryCloudingRepository();
    const sync = new SyncCloudingHistory(repo);

    await sync.execute('u1', [{ day: '2026-07-01', count: 0 }]);

    expect(await repo.getForDay('u1', '2026-07-01')).toBeNull();
  });

  test('rejects malformed days and negative counts', async () => {
    const repo = new InMemoryCloudingRepository();
    const sync = new SyncCloudingHistory(repo);

    await expect(
      sync.execute('u1', [{ day: '07/01/2026', count: 1 }]),
    ).rejects.toThrow(InvalidHistoryPayload);
    await expect(
      sync.execute('u1', [{ day: '2026-07-01', count: -1 }]),
    ).rejects.toThrow(InvalidHistoryPayload);
  });
});
