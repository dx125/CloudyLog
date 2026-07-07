import { Hono } from 'hono';

import type { MyProfile } from '../../application/use-cases/get-my-profile';
import type { AppBindings } from '../app';
import { requireAuth } from '../middleware/auth';

export const meRoutes = new Hono<AppBindings>();

meRoutes.use('*', requireAuth);

meRoutes.get('/', async (c) => {
  const profile = await c.get('container').getMyProfile.execute(c.get('userId'));
  return c.json(toProfileResponse(profile));
});

meRoutes.patch('/', async (c) => {
  const body = await c.req.json<{
    displayName?: string;
    country?: string | null;
  }>();
  if (body.displayName === undefined && body.country === undefined) {
    return c.json({ error: 'displayName or country is required' }, 400);
  }
  await c.get('container').updateMyProfile.execute(c.get('userId'), {
    displayName: body.displayName,
    country: body.country,
  });
  const profile = await c.get('container').getMyProfile.execute(c.get('userId'));
  return c.json(toProfileResponse(profile));
});

function toProfileResponse(profile: MyProfile) {
  return {
    user: {
      id: profile.user.id,
      email: profile.user.email,
      displayName: profile.user.displayName,
      country: profile.user.country,
      createdAt: profile.user.createdAt.toISOString(),
    },
    subscription: {
      tier: profile.subscription.tier,
      status: profile.subscription.status,
      expiresAt: profile.subscription.expiresAt?.toISOString() ?? null,
    },
  };
}
