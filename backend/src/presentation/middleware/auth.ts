import type { MiddlewareHandler } from 'hono';

import type { AppBindings } from '../app';

export const requireAuth: MiddlewareHandler<AppBindings> = async (c, next) => {
  const header = c.req.header('Authorization');
  if (!header?.startsWith('Bearer ')) {
    return c.json({ error: 'unauthorized' }, 401);
  }
  const token = header.slice('Bearer '.length).trim();
  const claims = await c.get('container').tokens.verify(token);
  if (!claims) {
    return c.json({ error: 'unauthorized' }, 401);
  }
  c.set('userId', claims.userId);
  await next();
};
