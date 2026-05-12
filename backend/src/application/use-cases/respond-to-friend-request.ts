import type { FriendshipRepository } from '../ports/friendship-repository';

export class FriendRequestNotFound extends Error {
  constructor() {
    super('Friend request not found');
    this.name = 'FriendRequestNotFound';
  }
}

export class FriendRequestNotPending extends Error {
  constructor() {
    super('Friend request is not pending');
    this.name = 'FriendRequestNotPending';
  }
}

export class RespondToFriendRequest {
  constructor(private readonly friendships: FriendshipRepository) {}

  async execute(
    requesterId: string,
    addresseeId: string,
    accept: boolean,
  ): Promise<void> {
    const pair = await this.friendships.findExact(requesterId, addresseeId);
    if (!pair) throw new FriendRequestNotFound();
    if (pair.status !== 'pending') throw new FriendRequestNotPending();
    await this.friendships.updateStatus(
      requesterId,
      addresseeId,
      accept ? 'accepted' : 'blocked',
    );
  }
}
