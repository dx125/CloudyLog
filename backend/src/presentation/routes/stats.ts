import { Hono } from 'hono';

import type { AppBindings } from '../app';
import { requireAuth } from '../middleware/auth';

export const statsRoutes = new Hono<AppBindings>();

statsRoutes.use('*', requireAuth);

statsRoutes.get('/today', async (c) => {
  const stats = await c.get('container').getTodayStats.execute(c.get('userId'));
  return c.json(stats);
});
