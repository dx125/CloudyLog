import type { Clock } from '../ports/clock';
import type { CloudingRepository } from '../ports/clouding-repository';
import type { SubscriptionRepository } from '../ports/subscription-repository';
import type {
  NewUser,
  UserProfilePatch,
  UserRepository,
} from '../ports/user-repository';
import {
  WORLDWIDE_SCOPE,
  type CloudingEntry,
  type DailyAggregate,
} from '../../domain/clouding';
import type { Subscription } from '../../domain/subscription';
import type { AuthProvider, User, UserIdentity } from '../../domain/user';

export class FixedClock implements Clock {
  constructor(private readonly fixed: Date) {}
  now(): Date {
    return this.fixed;
  }
  today(): string {
    return this.fixed.toISOString().slice(0, 10);
  }
}

export class InMemoryCloudingRepository implements CloudingRepository {
  entries = new Map<string, CloudingEntry>(); // key `${userId}|${day}`
  aggregates = new Map<string, DailyAggregate>(); // key `${day}|${country}`

  private key(userId: string, day: string): string {
    return `${userId}|${day}`;
  }

  async getForDay(userId: string, day: string): Promise<CloudingEntry | null> {
    return this.entries.get(this.key(userId, day)) ?? null;
  }

  async incrementForDay(
    userId: string,
    day: string,
    delta: number,
  ): Promise<CloudingEntry> {
    const existing = await this.getForDay(userId, day);
    return this.setForDay(userId, day, (existing?.count ?? 0) + delta);
  }

  async setForDay(
    userId: string,
    day: string,
    count: number,
  ): Promise<CloudingEntry> {
    const entry: CloudingEntry = {
      userId,
      day,
      count,
      updatedAt: new Date(),
    };
    this.entries.set(this.key(userId, day), entry);
    return entry;
  }

  async mergeMaxForDay(
    userId: string,
    day: string,
    count: number,
  ): Promise<CloudingEntry> {
    const existing = await this.getForDay(userId, day);
    return this.setForDay(userId, day, Math.max(existing?.count ?? 0, count));
  }

  async getAllForUser(userId: string): Promise<CloudingEntry[]> {
    return [...this.entries.values()].filter((e) => e.userId === userId);
  }

  async getCountsForUsers(
    userIds: string[],
    day: string,
  ): Promise<Map<string, number>> {
    const result = new Map<string, number>();
    for (const id of userIds) {
      const entry = await this.getForDay(id, day);
      if (entry) result.set(id, entry.count);
    }
    return result;
  }

  async computeDailyAggregates(): Promise<DailyAggregate[]> {
    throw new Error('not needed in these tests');
  }

  async saveAggregate(aggregate: DailyAggregate): Promise<void> {
    this.aggregates.set(`${aggregate.day}|${aggregate.country}`, aggregate);
  }

  async getAggregate(
    day: string,
    country: string,
  ): Promise<DailyAggregate | null> {
    return this.aggregates.get(`${day}|${country}`) ?? null;
  }

  seedAggregate(
    day: string,
    country: string,
    distribution: Record<string, number>,
  ): void {
    const totalUsers = Object.values(distribution).reduce((a, b) => a + b, 0);
    this.aggregates.set(`${day}|${country}`, {
      day,
      country,
      totalUsers,
      p50: 0,
      p75: 0,
      p90: 0,
      distribution,
    });
  }
}

export { WORLDWIDE_SCOPE };

export class InMemorySubscriptionRepository implements SubscriptionRepository {
  subscriptions = new Map<string, Subscription>();

  async getForUser(userId: string): Promise<Subscription | null> {
    return this.subscriptions.get(userId) ?? null;
  }

  async upsert(subscription: Subscription): Promise<void> {
    this.subscriptions.set(subscription.userId, subscription);
  }
}

export class InMemoryUserRepository implements UserRepository {
  users = new Map<string, User>();
  private nextId = 1;

  async findById(id: string): Promise<User | null> {
    return this.users.get(id) ?? null;
  }

  async findByEmail(email: string): Promise<User | null> {
    for (const user of this.users.values()) {
      if (user.email === email.toLowerCase()) return user;
    }
    return null;
  }

  async findByProvider(
    _provider: AuthProvider,
    _providerSubject: string,
  ): Promise<User | null> {
    return null;
  }

  async getPasswordHash(): Promise<string | null> {
    return null;
  }

  async create(user: NewUser): Promise<User> {
    const created: User = {
      id: `u${this.nextId++}`,
      email: user.email.toLowerCase(),
      displayName: user.displayName,
      country: user.country ?? null,
      createdAt: new Date(),
    };
    this.users.set(created.id, created);
    return created;
  }

  async linkIdentity(_identity: UserIdentity): Promise<void> {}

  async updateProfile(userId: string, patch: UserProfilePatch): Promise<User> {
    const user = this.users.get(userId);
    if (!user) throw new Error('User not found');
    const updated: User = {
      ...user,
      displayName: patch.displayName ?? user.displayName,
      country: patch.country !== undefined ? patch.country : user.country,
    };
    this.users.set(userId, updated);
    return updated;
  }
}
