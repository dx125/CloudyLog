import type { AuthProvider, User, UserIdentity } from '../../domain/user';

export interface NewUser {
  email: string;
  displayName: string;
  passwordHash?: string;
  country?: string | null;
}

export interface UserProfilePatch {
  displayName?: string;
  country?: string | null;
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
  updateProfile(userId: string, patch: UserProfilePatch): Promise<User>;
}
