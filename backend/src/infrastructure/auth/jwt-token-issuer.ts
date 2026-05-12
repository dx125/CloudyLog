import { SignJWT, jwtVerify } from 'jose';

import type { TokenIssuer } from '../../application/ports/token-issuer';

export class JwtTokenIssuer implements TokenIssuer {
  private readonly secret: Uint8Array;

  constructor(
    secret: string,
    private readonly ttlSeconds: number = 60 * 60 * 24 * 30,
  ) {
    if (secret.length < 32) {
      throw new Error('JWT secret must be at least 32 characters');
    }
    this.secret = new TextEncoder().encode(secret);
  }

  async issue(userId: string): Promise<string> {
    return new SignJWT({ sub: userId })
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuedAt()
      .setExpirationTime(`${this.ttlSeconds}s`)
      .sign(this.secret);
  }

  async verify(token: string): Promise<{ userId: string } | null> {
    try {
      const { payload } = await jwtVerify(token, this.secret);
      return payload.sub ? { userId: payload.sub } : null;
    } catch {
      return null;
    }
  }
}
