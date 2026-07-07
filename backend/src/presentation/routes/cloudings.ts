import { Hono } from 'hono';

import type { HistoryEntryInput } from '../../application/use-cases/sync-clouding-history';
import type { AppBindings } from '../app';
import { requireAuth } from '../middleware/auth';
import { requirePro } from '../middleware/subscription';

export const cloudingRoutes = new Hono<AppBindings>();

// Server-side storage is a Pro feature; free tier keeps data on-device.
cloudingRoutes.use('*', requireAuth, requirePro);

cloudingRoutes.post('/today/increment', async (c) => {
  const entry = await c.get('container').recordClouding.execute(c.get('userId'));
  return c.json({ day: entry.day, count: entry.count });
});

cloudingRoutes.put('/today', async (c) => {
  const body = await c.req.json<{ count?: number }>();
  if (typeof body.count !== 'number' || !Number.isInteger(body.count) || body.count < 0) {
    return c.json({ error: 'count must be a non-negative integer' }, 400);
  }
  const entry = await c
    .get('container')
    .setTodayClouding.execute(c.get('userId'), body.count);
  return c.json({ day: entry.day, count: entry.count });
});

cloudingRoutes.get('/', async (c) => {
  const entries = await c
    .get('container')
    .getCloudingHistory.execute(c.get('userId'));
  return c.json({
    entries: entries.map((e) => ({ day: e.day, count: e.count })),
  });
});

cloudingRoutes.post('/sync', async (c) => {
  const body = await c.req.json<{ entries?: HistoryEntryInput[] }>();
  if (!Array.isArray(body.entries)) {
    return c.json({ error: 'entries array is required' }, 400);
  }
  const merged = await c
    .get('container')
    .syncCloudingHistory.execute(c.get('userId'), body.entries);
  return c.json({
    entries: merged.map((e) => ({ day: e.day, count: e.count })),
  });
});
