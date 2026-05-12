import { Hono } from 'hono';

import type { AppBindings } from '../app';
import { requireAuth } from '../middleware/auth';

export const cloudingRoutes = new Hono<AppBindings>();

cloudingRoutes.use('*', requireAuth);

cloudingRoutes.post('/today/increment', async (c) => {
  const entry = await c.get('container').recordClouding.execute(c.get('userId'));
  return c.json({ day: entry.day, count: entry.count });
});
