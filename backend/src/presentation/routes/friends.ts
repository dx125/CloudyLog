import { Hono } from 'hono';

import type { AppBindings } from '../app';
import { requireAuth } from '../middleware/auth';

export const friendRoutes = new Hono<AppBindings>();

friendRoutes.use('*', requireAuth);

friendRoutes.post('/requests', async (c) => {
  const body = await c.req.json<{ email?: string }>();
  if (!body.email) {
    return c.json({ error: 'email is required' }, 400);
  }
  const friendship = await c
    .get('container')
    .sendFriendRequest.execute(c.get('userId'), body.email);
  return c.json({ friendship });
});

friendRoutes.post('/requests/:requesterId/respond', async (c) => {
  const requesterId = c.req.param('requesterId');
  const body = await c.req.json<{ accept?: boolean }>();
  await c
    .get('container')
    .respondToFriendRequest.execute(
      requesterId,
      c.get('userId'),
      body.accept === true,
    );
  return c.json({ ok: true });
});

friendRoutes.get('/today', async (c) => {
  const friends = await c.get('container').listFriendsToday.execute(c.get('userId'));
  return c.json({ friends });
});
