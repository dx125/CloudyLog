import type { GoogleIdTokenVerifier } from '../ports/google-id-token-verifier';
import type { TokenIssuer } from '../ports/token-issuer';
import type { UserRepository } from '../ports/user-repository';
import { normalizeCountry, type SignInResult } from './sign-up-credentials';

export class AccountLinkingRequired extends Error {
  constructor() {
    super(
      'This email is already registered with a password. Sign in with your password to link Google.',
    );
    this.name = 'AccountLinkingRequired';
  }
}

export class SignInWithGoogle {
  constructor(
    private readonly users: UserRepository,
    private readonly google: GoogleIdTokenVerifier,
    private readonly tokens: TokenIssuer,
  ) {}

  async execute(
    idToken: string,
    country?: string | null,
  ): Promise<SignInResult> {
    const claims = await this.google.verify(idToken);
    const email = claims.email.toLowerCase();

    // Already linked to a Google identity: sign in directly.
    const linked = await this.users.findByProvider('google', claims.sub);
    if (linked) {
      return { user: linked, token: await this.tokens.issue(linked.id) };
    }

    // Email already belongs to someone (e.g. a credentials-only account).
    // Do NOT auto-link — the Google email claim alone is not proof the caller
    // owns the existing account. Require an explicit, authenticated link step.
    const existingByEmail = await this.users.findByEmail(email);
    if (existingByEmail) {
      throw new AccountLinkingRequired();
    }

    // Fresh sign-up via Google.
    const user = await this.users.create(
      {
        email,
        displayName: claims.name?.trim() || email,
        country: normalizeCountry(country),
      },
      { provider: 'google', providerSubject: claims.sub },
    );
    return { user, token: await this.tokens.issue(user.id) };
  }
}
