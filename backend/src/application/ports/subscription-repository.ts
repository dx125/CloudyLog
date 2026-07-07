import type { Subscription } from '../../domain/subscription';

export interface SubscriptionRepository {
  getForUser(userId: string): Promise<Subscription | null>;
  upsert(subscription: Subscription): Promise<void>;
}
