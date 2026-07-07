import { describe, expect, test } from 'vitest';

import { MockPurchaseValidator } from '../../infrastructure/billing/mock-purchase-validator';
import { InvalidPurchase } from '../ports/purchase-validator';
import { ActivateSubscription } from './activate-subscription';
import { CancelSubscription, NoActiveSubscription } from './cancel-subscription';
import {
  FixedClock,
  InMemorySubscriptionRepository,
} from './fakes.test-helpers';
import { GetSubscriptionStatus } from './get-subscription-status';

const NOW = new Date('2026-07-06T12:00:00Z');

function setup() {
  const clock = new FixedClock(NOW);
  const repo = new InMemorySubscriptionRepository();
  const validator = new MockPurchaseValidator(clock);
  return {
    repo,
    activate: new ActivateSubscription(repo, validator, clock),
    cancel: new CancelSubscription(repo, clock),
    status: new GetSubscriptionStatus(repo, clock),
  };
}

describe('subscription lifecycle', () => {
  test('a user without a subscription is on the free tier', async () => {
    const { status } = setup();
    const state = await status.execute('u1');
    expect(state).toMatchObject({ tier: 'free', isPro: false, status: null });
  });

  test('mock activation grants 30 days of pro', async () => {
    const { activate, status } = setup();
    await activate.execute('u1', 'mock', 'mock-receipt');
    const state = await status.execute('u1');
    expect(state.isPro).toBe(true);
    expect(state.tier).toBe('pro');
    expect(state.expiresAt?.toISOString()).toBe('2026-08-05T12:00:00.000Z');
  });

  test('activation rejects unsupported providers', async () => {
    const { activate } = setup();
    await expect(
      activate.execute('u1', 'google_play', 'receipt'),
    ).rejects.toThrow(InvalidPurchase);
  });

  test('re-activation keeps the original start date', async () => {
    const { activate, repo } = setup();
    await activate.execute('u1', 'mock', 'r1');
    const first = await repo.getForUser('u1');
    await activate.execute('u1', 'mock', 'r2');
    const second = await repo.getForUser('u1');
    expect(second?.startedAt).toEqual(first?.startedAt);
    expect(second?.status).toBe('active');
  });

  test('cancel keeps entitlement until expiry', async () => {
    const { activate, cancel, status } = setup();
    await activate.execute('u1', 'mock', 'r1');
    const canceled = await cancel.execute('u1');
    expect(canceled.status).toBe('canceled');
    const state = await status.execute('u1');
    expect(state.isPro).toBe(true);
    expect(state.status).toBe('canceled');
  });

  test('cancel without an active subscription fails', async () => {
    const { cancel } = setup();
    await expect(cancel.execute('u1')).rejects.toThrow(NoActiveSubscription);
  });
});
