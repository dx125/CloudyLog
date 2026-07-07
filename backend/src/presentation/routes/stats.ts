import { Hono } from 'hono';

import type { StatsScope } from '../../application/use-cases/get-today-stats';
import type { AppBindings } from '../app';
import { requireAuth } from '../middleware/auth';
import { requirePro } from '../middleware/subscription';

export const statsRoutes = new Hono<AppBindings>();

// Comparisons against other users are a Pro feature.
statsRoutes.use('*', requireAuth, requirePro);

statsRoutes.get('/today', async (c) => {
  const rawScope = c.req.query('scope') ?? 'worldwide';
  if (rawScope !== 'worldwide' && rawScope !== 'country') {
    return c.json({ error: "scope must be 'worldwide' or 'country'" }, 400);
  }
  const stats = await c
    .get('container')
    .getTodayStats.execute(c.get('userId'), rawScope as StatsScope);
  return c.json(stats);
});
