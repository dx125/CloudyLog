import { and, eq } from 'drizzle-orm';

import type {
  NewUser,
  UserRepository,
} from '../../application/ports/user-repository';
import type { AuthProvider, User, UserIdentity } from '../../domain/user';
import type { Db } from './client';
import { authIdentities, users } from './schema';

type UserRow = typeof users.$inferSelect;

export class DrizzleUserRepository implements UserRepository {
  constructor(private readonly db: Db) {}

  async findById(id: string): Promise<User | null> {
    const row = await this.db.query.users.findFirst({
      where: eq(users.id, id),
    });
    return row ? toDomain(row) : null;
  }

  async findByEmail(email: string): Promise<User | null> {
    const row = await this.db.query.users.findFirst({
      where: eq(users.email, email.toLowerCase()),
    });
    return row ? toDomain(row) : null;
  }

  async findByProvider(
    provider: AuthProvider,
    providerSubject: string,
  ): Promise<User | null> {
    const identity = await this.db.query.authIdentities.findFirst({
      where: and(
        eq(authIdentities.provider, provider),
        eq(authIdentities.providerSubject, providerSubject),
      ),
    });
    if (!identity) return null;
    return this.findById(identity.userId);
  }

  async getPasswordHash(userId: string): Promise<string | null> {
    const row = await this.db.query.users.findFirst({
      where: eq(users.id, userId),
      columns: { passwordHash: true },
    });
    return row?.passwordHash ?? null;
  }

  async create(
    user: NewUser,
    identity?: Omit<UserIdentity, 'userId'>,
  ): Promise<User> {
    const id = crypto.randomUUID();
    const [inserted] = await this.db
      .insert(users)
      .values({
        id,
        email: user.email.toLowerCase(),
        displayName: user.displayName,
        passwordHash: user.passwordHash ?? null,
      })
      .returning();
    if (!inserted) {
      throw new Error('Failed to create user');
    }
    if (identity) {
      await this.db
        .insert(authIdentities)
        .values({ userId: id, ...identity })
        .onConflictDoNothing();
    }
    return toDomain(inserted);
  }

  async linkIdentity(identity: UserIdentity): Promise<void> {
    await this.db
      .insert(authIdentities)
      .values(identity)
      .onConflictDoNothing();
  }
}

function toDomain(row: UserRow): User {
  return {
    id: row.id,
    email: row.email,
    displayName: row.displayName,
    createdAt: row.createdAt,
  };
}
