import type { Clock } from '../ports/clock';
import type { CloudingRepository } from '../ports/clouding-repository';
import type { FriendshipRepository } from '../ports/friendship-repository';
import type { UserRepository } from '../ports/user-repository';

export interface FriendToday {
  userId: string;
  displayName: string;
  count: number;
}

export class ListFriendsToday {
  constructor(
    private readonly friendships: FriendshipRepository,
    private readonly cloudings: CloudingRepository,
    private readonly users: UserRepository,
    private readonly clock: Clock,
  ) {}

  async execute(userId: string): Promise<FriendToday[]> {
    const friendIds = await this.friendships.getFriendIdsOf(userId);
    if (friendIds.length === 0) return [];
    const day = this.clock.today();
    const counts = await this.cloudings.getCountsForUsers(friendIds, day);
    const friends = await Promise.all(
      friendIds.map((id) => this.users.findById(id)),
    );
    const result: FriendToday[] = [];
    for (const friend of friends) {
      if (!friend) continue;
      result.push({
        userId: friend.id,
        displayName: friend.displayName,
        count: counts.get(friend.id) ?? 0,
      });
    }
    result.sort((a, b) => b.count - a.count);
    return result;
  }
}
