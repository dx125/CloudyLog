import { and, eq, or } from 'drizzle-orm';

import type { FriendshipRepository } from '../../application/ports/friendship-repository';
import type { Friendship, FriendshipStatus } from '../../domain/friendship';
import type { Db } from './client';
import { friendships } from './schema';

type Row = typeof friendships.$inferSelect;

export class DrizzleFriendshipRepository implements FriendshipRepository {
  constructor(private readonly db: Db) {}

  async request(
    requesterId: string,
    addresseeId: string,
  ): Promise<Friendship> {
    const [row] = await this.db
      .insert(friendships)
      .values({ requesterId, addresseeId, status: 'pending' })
      .onConflictDoNothing()
      .returning();
    if (row) return toDomain(row);
    const existing = await this.findBetween(requesterId, addresseeId);
    if (!existing) throw new Error('Failed to create friendship');
    return existing;
  }

  async updateStatus(
    requesterId: string,
    addresseeId: string,
    status: FriendshipStatus,
  ): Promise<void> {
    await this.db
      .update(friendships)
      .set({ status })
      .where(
        and(
          eq(friendships.requesterId, requesterId),
          eq(friendships.addresseeId, addresseeId),
        ),
      );
  }

  async getFriendIdsOf(userId: string): Promise<string[]> {
    const rows = await this.db
      .select()
      .from(friendships)
      .where(
        and(
          eq(friendships.status, 'accepted'),
          or(
            eq(friendships.requesterId, userId),
            eq(friendships.addresseeId, userId),
          ),
        ),
      );
    return rows.map((row) =>
      row.requesterId === userId ? row.addresseeId : row.requesterId,
    );
  }

  async getPendingRequestsFor(userId: string): Promise<Friendship[]> {
    const rows = await this.db
      .select()
      .from(friendships)
      .where(
        and(
          eq(friendships.status, 'pending'),
          eq(friendships.addresseeId, userId),
        ),
      );
    return rows.map(toDomain);
  }

  async findBetween(a: string, b: string): Promise<Friendship | null> {
    const row = await this.db.query.friendships.findFirst({
      where: or(
        and(eq(friendships.requesterId, a), eq(friendships.addresseeId, b)),
        and(eq(friendships.requesterId, b), eq(friendships.addresseeId, a)),
      ),
    });
    return row ? toDomain(row) : null;
  }

  async findExact(
    requesterId: string,
    addresseeId: string,
  ): Promise<Friendship | null> {
    const row = await this.db.query.friendships.findFirst({
      where: and(
        eq(friendships.requesterId, requesterId),
        eq(friendships.addresseeId, addresseeId),
      ),
    });
    return row ? toDomain(row) : null;
  }
}

function toDomain(row: Row): Friendship {
  return {
    requesterId: row.requesterId,
    addresseeId: row.addresseeId,
    status: row.status as FriendshipStatus,
    createdAt: row.createdAt,
  };
}
