import type { UserRepository } from '../ports/user-repository';
import type { User } from '../../domain/user';
import type {
  GetSubscriptionStatus,
  SubscriptionState,
} from './get-subscription-status';

export class ProfileNotFound extends Error {
  constructor() {
    super('Profile not found');
    this.name = 'ProfileNotFound';
  }
}

export interface MyProfile {
  user: User;
  subscription: SubscriptionState;
}

export class GetMyProfile {
  constructor(
    private readonly users: UserRepository,
    private readonly subscriptionStatus: GetSubscriptionStatus,
  ) {}

  async execute(userId: string): Promise<MyProfile> {
    const user = await this.users.findById(userId);
    if (!user) throw new ProfileNotFound();
    const subscription = await this.subscriptionStatus.execute(userId);
    return { user, subscription };
  }
}
