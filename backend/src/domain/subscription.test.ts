import { describe, expect, test } from 'vitest';

import {
  isSubscriptionActive,
  tierFor,
  type Subscription,
} from './subscription';

const NOW = new Date('2026-07-06T12:00:00Z');

function subscription(overrides: Partial<Subscription> = {}): Subscription {
  return {
    userId: 'u1',
    status: 'active',
    provider: 'mock',
    startedAt: new Date('2026-06-06T12:00:00Z'),
    expiresAt: new Date('2026-08-06T12:00:00Z'),
    updatedAt: NOW,
    ...overrides,
  };
}

describe('isSubscriptionActive', () => {
  test('null subscription is not active', () => {
    expect(isSubscriptionActive(null, NOW)).toBe(false);
  });

  test('unexpired subscription is active', () => {
    expect(isSubscriptionActive(subscription(), NOW)).toBe(true);
  });

  test('canceled subscription stays active until it expires', () => {
    expect(isSubscriptionActive(subscription({ status: 'canceled' }), NOW)).toBe(
      true,
    );
  });

  test('expired subscription is not active regardless of status', () => {
    const expired = subscription({
      expiresAt: new Date('2026-07-06T11:59:59Z'),
    });
    expect(isSubscriptionActive(expired, NOW)).toBe(false);
    expect(
      isSubscriptionActive({ ...expired, status: 'canceled' }, NOW),
    ).toBe(false);
  });
});

describe('tierFor', () => {
  test('maps entitlement to pro/free', () => {
    expect(tierFor(subscription(), NOW)).toBe('pro');
    expect(tierFor(null, NOW)).toBe('free');
    expect(
      tierFor(subscription({ expiresAt: new Date('2026-01-01') }), NOW),
    ).toBe('free');
  });
});
