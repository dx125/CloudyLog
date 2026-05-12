import type { PasswordHasher } from '../ports/password-hasher';
import type { TokenIssuer } from '../ports/token-issuer';
import type { UserRepository } from '../ports/user-repository';
import type { SignInResult } from './sign-up-credentials';

export class InvalidCredentials extends Error {
  constructor() {
    super('Invalid credentials');
  }
}

export class SignInWithCredentials {
  constructor(
    private readonly users: UserRepository,
    private readonly hasher: PasswordHasher,
    private readonly tokens: TokenIssuer,
  ) {}

  async execute(email: string, password: string): Promise<SignInResult> {
    const normalizedEmail = email.trim().toLowerCase();
    const user = await this.users.findByEmail(normalizedEmail);
    if (!user) throw new InvalidCredentials();
    const hash = await this.users.getPasswordHash(user.id);
    if (!hash) throw new InvalidCredentials();
    const ok = await this.hasher.verify(password, hash);
    if (!ok) throw new InvalidCredentials();
    const token = await this.tokens.issue(user.id);
    return { user, token };
  }
}
