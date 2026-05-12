import type { FriendshipRepository } from '../ports/friendship-repository';
import type { UserRepository } from '../ports/user-repository';
import type { Friendship } from '../../domain/friendship';

export class UserNotFound extends Error {
  constructor() {
    super('User not found');
  }
}

export class CannotBefriendSelf extends Error {
  constructor() {
    super('Cannot befriend yourself');
  }
}

export class SendFriendRequest {
  constructor(
    private readonly friendships: FriendshipRepository,
    private readonly users: UserRepository,
  ) {}

  async execute(
    requesterId: string,
    addresseeEmail: string,
  ): Promise<Friendship> {
    const addressee = await this.users.findByEmail(
      addresseeEmail.trim().toLowerCase(),
    );
    if (!addressee) throw new UserNotFound();
    if (addressee.id === requesterId) throw new CannotBefriendSelf();
    const existing = await this.friendships.findBetween(
      requesterId,
      addressee.id,
    );
    if (existing) return existing;
    return this.friendships.request(requesterId, addressee.id);
  }
}
