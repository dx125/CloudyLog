import { Hono } from 'hono';
import { cors } from 'hono/cors';

import type { Container } from '../composition';
import type { Env } from '../env';
import { toErrorResponse } from './error-response';
import { authRoutes } from './routes/auth';
import { cloudingRoutes } from './routes/cloudings';
import { friendRoutes } from './routes/friends';
import { statsRoutes } from './routes/stats';

export type AppBindings = {
  Bindings: Env;
  Variables: {
    container: Container;
    userId: string;
  };
};

export function createApp(resolveContainer: (env: Env) => Container) {
  const app = new Hono<AppBindings>();

  app.use('*', cors());
  app.use('*', async (c, next) => {
    c.set('container', resolveContainer(c.env));
    await next();
  });

  app.get('/healthz', (c) => c.json({ ok: true }));
  app.route('/auth', authRoutes);
  app.route('/cloudings', cloudingRoutes);
  app.route('/stats', statsRoutes);
  app.route('/friends', friendRoutes);

  app.onError((err, c) => toErrorResponse(err, c));

  return app;
}
