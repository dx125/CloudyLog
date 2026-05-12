import type { AuthProvider, User, UserIdentity } from '../../domain/user';

export interface NewUser {
  email: string;
  displayName: string;
  passwordHash?: string;
}

export interface UserRepository {
  findById(id: string): Promise<User | null>;
  findByEmail(email: string): Promise<User | null>;
  findByProvider(
    provider: AuthProvider,
    providerSubject: string,
  ): Promise<User | null>;
  getPasswordHash(userId: string): Promise<string | null>;
  create(
    user: NewUser,
    identity?: Omit<UserIdentity, 'userId'>,
  ): Promise<User>;
  linkIdentity(identity: UserIdentity): Promise<void>;
}
