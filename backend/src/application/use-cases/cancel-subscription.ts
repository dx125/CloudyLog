import type { Clock } from '../ports/clock';
import type { SubscriptionRepository } from '../ports/subscription-repository';
import {
  isSubscriptionActive,
  type Subscription,
} from '../../domain/subscription';

export class NoActiveSubscription extends Error {
  constructor() {
    super('No active subscription');
    this.name = 'NoActiveSubscription';
  }
}

/** Turns off renewal. The entitlement keeps running until expiresAt. */
export class CancelSubscription {
  constructor(
    private readonly subscriptions: SubscriptionRepository,
    private readonly clock: Clock,
  ) {}

  async execute(userId: string): Promise<Subscription> {
    const existing = await this.subscriptions.getForUser(userId);
    const now = this.clock.now();
    if (!existing || !isSubscriptionActive(existing, now)) {
      throw new NoActiveSubscription();
    }
    const canceled: Subscription = {
      ...existing,
      status: 'canceled',
      updatedAt: now,
    };
    await this.subscriptions.upsert(canceled);
    return canceled;
  }
}
