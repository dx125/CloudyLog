import type { Friendship, FriendshipStatus } from '../../domain/friendship';

export interface FriendshipRepository {
  request(requesterId: string, addresseeId: string): Promise<Friendship>;
  updateStatus(
    requesterId: string,
    addresseeId: string,
    status: FriendshipStatus,
  ): Promise<void>;
  getFriendIdsOf(userId: string): Promise<string[]>;
  getPendingRequestsFor(userId: string): Promise<Friendship[]>;
  /** Unordered: finds a row matching either direction. */
  findBetween(a: string, b: string): Promise<Friendship | null>;
  /** Directional: finds only the row (requesterId -> addresseeId). */
  findExact(
    requesterId: string,
    addresseeId: string,
  ): Promise<Friendship | null>;
}
