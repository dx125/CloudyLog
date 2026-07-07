import type { Clock } from '../ports/clock';
import type { PurchaseValidator } from '../ports/purchase-validator';
import type { SubscriptionRepository } from '../ports/subscription-repository';
import type { Subscription } from '../../domain/subscription';

export class ActivateSubscription {
  constructor(
    private readonly subscriptions: SubscriptionRepository,
    private readonly validator: PurchaseValidator,
    private readonly clock: Clock,
  ) {}

  async execute(
    userId: string,
    provider: string,
    receipt: string,
  ): Promise<Subscription> {
    const validation = await this.validator.validate(userId, provider, receipt);
    const now = this.clock.now();
    const existing = await this.subscriptions.getForUser(userId);
    const subscription: Subscription = {
      userId,
      status: 'active',
      provider: validation.provider,
      startedAt: existing?.startedAt ?? now,
      expiresAt: validation.expiresAt,
      updatedAt: now,
    };
    await this.subscriptions.upsert(subscription);
    return subscription;
  }
}
