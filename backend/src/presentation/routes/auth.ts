import { Hono } from 'hono';

import type { User } from '../../domain/user';
import type { AppBindings } from '../app';

export const authRoutes = new Hono<AppBindings>();

authRoutes.post('/signup', async (c) => {
  const body = await c.req.json<{
    email?: string;
    password?: string;
    displayName?: string;
    country?: string;
  }>();
  if (!body.email || !body.password || !body.displayName) {
    return c.json(
      { error: 'email, password and displayName are required' },
      400,
    );
  }
  const result = await c
    .get('container')
    .signUpWithCredentials.execute(
      body.email,
      body.password,
      body.displayName,
      body.country,
    );
  return c.json({ user: toPublicUser(result.user), token: result.token });
});

authRoutes.post('/signin', async (c) => {
  const body = await c.req.json<{ email?: string; password?: string }>();
  if (!body.email || !body.password) {
    return c.json({ error: 'email and password are required' }, 400);
  }
  const result = await c
    .get('container')
    .signInWithCredentials.execute(body.email, body.password);
  return c.json({ user: toPublicUser(result.user), token: result.token });
});

authRoutes.post('/google', async (c) => {
  const body = await c.req.json<{ idToken?: string; country?: string }>();
  if (!body.idToken) {
    return c.json({ error: 'idToken is required' }, 400);
  }
  const result = await c
    .get('container')
    .signInWithGoogle.execute(body.idToken, body.country);
  return c.json({ user: toPublicUser(result.user), token: result.token });
});

function toPublicUser(user: User) {
  return {
    id: user.id,
    email: user.email,
    displayName: user.displayName,
    country: user.country,
    createdAt: user.createdAt.toISOString(),
  };
}
