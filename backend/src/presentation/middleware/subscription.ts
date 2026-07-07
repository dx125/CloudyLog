import type { MiddlewareHandler } from 'hono';

import type { AppBindings } from '../app';

/**
 * Gates Pro-tier features (server storage, comparisons, friends). Must run
 * after requireAuth so userId is set.
 */
export const requirePro: MiddlewareHandler<AppBindings> = async (c, next) => {
  const state = await c
    .get('container')
    .getSubscriptionStatus.execute(c.get('userId'));
  if (!state.isPro) {
    return c.json({ error: 'pro_required' }, 403);
  }
  await next();
};
