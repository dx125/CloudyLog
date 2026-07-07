import { Hono } from 'hono';

import type { Subscription } from '../../domain/subscription';
import type { AppBindings } from '../app';
import { requireAuth } from '../middleware/auth';

export const subscriptionRoutes = new Hono<AppBindings>();

subscriptionRoutes.use('*', requireAuth);

subscriptionRoutes.get('/', async (c) => {
  const state = await c
    .get('container')
    .getSubscriptionStatus.execute(c.get('userId'));
  return c.json({
    tier: state.tier,
    status: state.status,
    expiresAt: state.expiresAt?.toISOString() ?? null,
  });
});

subscriptionRoutes.post('/activate', async (c) => {
  const body = await c.req.json<{ provider?: string; receipt?: string }>();
  if (!body.provider || !body.receipt) {
    return c.json({ error: 'provider and receipt are required' }, 400);
  }
  const subscription = await c
    .get('container')
    .activateSubscription.execute(c.get('userId'), body.provider, body.receipt);
  return c.json(toSubscriptionResponse(subscription));
});

subscriptionRoutes.post('/cancel', async (c) => {
  const subscription = await c
    .get('container')
    .cancelSubscription.execute(c.get('userId'));
  return c.json(toSubscriptionResponse(subscription));
});

function toSubscriptionResponse(subscription: Subscription) {
  return {
    tier: 'pro' as const,
    status: subscription.status,
    provider: subscription.provider,
    expiresAt: subscription.expiresAt.toISOString(),
  };
}
