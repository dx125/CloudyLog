import { and, eq, inArray, sql } from 'drizzle-orm';

import type { CloudingRepository } from '../../application/ports/clouding-repository';
import type { CloudingEntry, DailyAggregate } from '../../domain/clouding';
import type { Db } from './client';
import { cloudingEntries, dailyAggregates } from './schema';

type EntryRow = typeof cloudingEntries.$inferSelect;

export class DrizzleCloudingRepository implements CloudingRepository {
  constructor(private readonly db: Db) {}

  async getForDay(userId: string, day: string): Promise<CloudingEntry | null> {
    const row = await this.db.query.cloudingEntries.findFirst({
      where: and(
        eq(cloudingEntries.userId, userId),
        eq(cloudingEntries.day, day),
      ),
    });
    return row ? toDomain(row) : null;
  }

  async incrementForDay(
    userId: string,
    day: string,
    delta: number,
  ): Promise<CloudingEntry> {
    const [row] = await this.db
      .insert(cloudingEntries)
      .values({ userId, day, count: delta, updatedAt: new Date() })
      .onConflictDoUpdate({
        target: [cloudingEntries.userId, cloudingEntries.day],
        set: {
          count: sql`${cloudingEntries.count} + ${delta}`,
          updatedAt: new Date(),
        },
      })
      .returning();
    if (!row) throw new Error('Failed to increment clouding entry');
    return toDomain(row);
  }

  async setForDay(
    userId: string,
    day: string,
    count: number,
  ): Promise<CloudingEntry> {
    const [row] = await this.db
      .insert(cloudingEntries)
      .values({ userId, day, count, updatedAt: new Date() })
      .onConflictDoUpdate({
        target: [cloudingEntries.userId, cloudingEntries.day],
        set: { count, updatedAt: new Date() },
      })
      .returning();
    if (!row) throw new Error('Failed to set clouding entry');
    return toDomain(row);
  }

  async getCountsForUsers(
    userIds: string[],
    day: string,
  ): Promise<Map<string, number>> {
    if (userIds.length === 0) return new Map();
    const rows = await this.db
      .select({
        userId: cloudingEntries.userId,
        count: cloudingEntries.count,
      })
      .from(cloudingEntries)
      .where(
        and(
          inArray(cloudingEntries.userId, userIds),
          eq(cloudingEntries.day, day),
        ),
      );
    return new Map(rows.map((r) => [r.userId, r.count]));
  }

  async computeDailyAggregate(day: string): Promise<DailyAggregate> {
    const rows = await this.db
      .select({ count: cloudingEntries.count })
      .from(cloudingEntries)
      .where(eq(cloudingEntries.day, day));
    const counts = rows.map((r) => r.count).sort((a, b) => a - b);
    const total = counts.length;
    const distribution: Record<string, number> = {};
    for (const c of counts) {
      const key = String(c);
      distribution[key] = (distribution[key] ?? 0) + 1;
    }
    const percentile = (p: number): number => {
      if (total === 0) return 0;
      const idx = Math.min(total - 1, Math.floor(p * total));
      return counts[idx] ?? 0;
    };
    return {
      day,
      totalUsers: total,
      p50: percentile(0.5),
      p75: percentile(0.75),
      p90: percentile(0.9),
      distribution,
    };
  }

  async saveAggregate(aggregate: DailyAggregate): Promise<void> {
    await this.db
      .insert(dailyAggregates)
      .values({
        day: aggregate.day,
        totalUsers: aggregate.totalUsers,
        p50: aggregate.p50,
        p75: aggregate.p75,
        p90: aggregate.p90,
        distribution: aggregate.distribution,
        computedAt: new Date(),
      })
      .onConflictDoUpdate({
        target: dailyAggregates.day,
        set: {
          totalUsers: aggregate.totalUsers,
          p50: aggregate.p50,
          p75: aggregate.p75,
          p90: aggregate.p90,
          distribution: aggregate.distribution,
          computedAt: new Date(),
        },
      });
  }

  async getAggregate(day: string): Promise<DailyAggregate | null> {
    const row = await this.db.query.dailyAggregates.findFirst({
      where: eq(dailyAggregates.day, day),
    });
    if (!row) return null;
    return {
      day: row.day,
      totalUsers: row.totalUsers,
      p50: row.p50,
      p75: row.p75,
      p90: row.p90,
      distribution: row.distribution as Record<string, number>,
    };
  }
}

function toDomain(row: EntryRow): CloudingEntry {
  return {
    userId: row.userId,
    day: row.day,
    count: row.count,
    updatedAt: row.updatedAt,
  };
}
