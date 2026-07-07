import type { FriendshipRepository } from '../ports/friendship-repository';
import type { UserRepository } from '../ports/user-repository';

export interface PendingFriendRequest {
  requesterId: string;
  requesterDisplayName: string;
  requesterEmail: string;
  createdAt: Date;
}

export class ListPendingFriendRequests {
  constructor(
    private readonly friendships: FriendshipRepository,
    private readonly users: UserRepository,
  ) {}

  async execute(userId: string): Promise<PendingFriendRequest[]> {
    const pending = await this.friendships.getPendingRequestsFor(userId);
    const requesters = await Promise.all(
      pending.map((request) => this.users.findById(request.requesterId)),
    );
    const result: PendingFriendRequest[] = [];
    for (let i = 0; i < pending.length; i++) {
      const requester = requesters[i];
      const request = pending[i];
      if (!requester || !request) continue;
      result.push({
        requesterId: requester.id,
        requesterDisplayName: requester.displayName,
        requesterEmail: requester.email,
        createdAt: request.createdAt,
      });
    }
    return result;
  }
}
