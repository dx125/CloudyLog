import type { PasswordHasher } from '../ports/password-hasher';
import type { TokenIssuer } from '../ports/token-issuer';
import type { UserRepository } from '../ports/user-repository';
import type { User } from '../../domain/user';

export interface SignInResult {
  user: User;
  token: string;
}

export class EmailAlreadyRegistered extends Error {
  constructor() {
    super('Email already registered');
    this.name = 'EmailAlreadyRegistered';
  }
}

export class SignUpWithCredentials {
  constructor(
    private readonly users: UserRepository,
    private readonly hasher: PasswordHasher,
    private readonly tokens: TokenIssuer,
  ) {}

  async execute(
    email: string,
    password: string,
    displayName: string,
  ): Promise<SignInResult> {
    const normalizedEmail = email.trim().toLowerCase();
    const existing = await this.users.findByEmail(normalizedEmail);
    if (existing) throw new EmailAlreadyRegistered();

    const passwordHash = await this.hasher.hash(password);
    let user: User;
    try {
      user = await this.users.create(
        {
          email: normalizedEmail,
          displayName: displayName.trim(),
          passwordHash,
        },
        { provider: 'credentials', providerSubject: normalizedEmail },
      );
    } catch (err) {
      // Possible race: another request inserted the same email between our
      // findByEmail check and the insert. Re-query to distinguish a duplicate
      // from a genuine infrastructure failure.
      const raced = await this.users.findByEmail(normalizedEmail);
      if (raced) throw new EmailAlreadyRegistered();
      throw err;
    }
    const token = await this.tokens.issue(user.id);
    return { user, token };
  }
}
