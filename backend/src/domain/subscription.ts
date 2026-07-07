export type SubscriptionTier = 'free' | 'pro';

/**
 * 'active'   — entitlement granted, renews (or is inside its paid window).
 * 'canceled' — user turned off renewal; entitlement persists until expiresAt.
 */
export type SubscriptionStatus = 'active' | 'canceled';

/** 'mock' is the development provider; store billing plugs in later. */
export type SubscriptionProvider = 'mock' | 'google_play' | 'app_store';

export interface Subscription {
  userId: string;
  status: SubscriptionStatus;
  provider: SubscriptionProvider;
  startedAt: Date;
  expiresAt: Date;
  updatedAt: Date;
}

/** Entitlement rule: a subscription grants Pro until it expires, even if the
 * user has canceled renewal. */
export function isSubscriptionActive(
  subscription: Subscription | null,
  now: Date,
): boolean {
  if (!subscription) return false;
  return subscription.expiresAt.getTime() > now.getTime();
}

export function tierFor(
  subscription: Subscription | null,
  now: Date,
): SubscriptionTier {
  return isSubscriptionActive(subscription, now) ? 'pro' : 'free';
}
