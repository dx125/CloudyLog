import type { Clock } from '../ports/clock';
import type { SubscriptionRepository } from '../ports/subscription-repository';
import {
  isSubscriptionActive,
  tierFor,
  type SubscriptionStatus,
  type SubscriptionTier,
} from '../../domain/subscription';

export interface SubscriptionState {
  tier: SubscriptionTier;
  /** Null when the user never had a subscription. */
  status: SubscriptionStatus | null;
  expiresAt: Date | null;
  isPro: boolean;
}

export class GetSubscriptionStatus {
  constructor(
    private readonly subscriptions: SubscriptionRepository,
    private readonly clock: Clock,
  ) {}

  async execute(userId: string): Promise<SubscriptionState> {
    const subscription = await this.subscriptions.getForUser(userId);
    const now = this.clock.now();
    return {
      tier: tierFor(subscription, now),
      status: subscription?.status ?? null,
      expiresAt: subscription?.expiresAt ?? null,
      isPro: isSubscriptionActive(subscription, now),
    };
  }
}
