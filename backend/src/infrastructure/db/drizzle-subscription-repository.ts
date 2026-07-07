import { eq } from 'drizzle-orm';

import type { SubscriptionRepository } from '../../application/ports/subscription-repository';
import type {
  Subscription,
  SubscriptionProvider,
  SubscriptionStatus,
} from '../../domain/subscription';
import type { Db } from './client';
import { subscriptions } from './schema';

type Row = typeof subscriptions.$inferSelect;

export class DrizzleSubscriptionRepository implements SubscriptionRepository {
  constructor(private readonly db: Db) {}

  async getForUser(userId: string): Promise<Subscription | null> {
    const row = await this.db.query.subscriptions.findFirst({
      where: eq(subscriptions.userId, userId),
    });
    return row ? toDomain(row) : null;
  }

  async upsert(subscription: Subscription): Promise<void> {
    await this.db
      .insert(subscriptions)
      .values({
        userId: subscription.userId,
        status: subscription.status,
        provider: subscription.provider,
        startedAt: subscription.startedAt,
        expiresAt: subscription.expiresAt,
        updatedAt: subscription.updatedAt,
      })
      .onConflictDoUpdate({
        target: subscriptions.userId,
        set: {
          status: subscription.status,
          provider: subscription.provider,
          startedAt: subscription.startedAt,
          expiresAt: subscription.expiresAt,
          updatedAt: subscription.updatedAt,
        },
      });
  }
}

function toDomain(row: Row): Subscription {
  return {
    userId: row.userId,
    status: row.status as SubscriptionStatus,
    provider: row.provider as SubscriptionProvider,
    startedAt: row.startedAt,
    expiresAt: row.expiresAt,
    updatedAt: row.updatedAt,
  };
}
