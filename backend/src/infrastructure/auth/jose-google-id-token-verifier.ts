import { createRemoteJWKSet, jwtVerify, type JWTPayload } from 'jose';

import {
  InvalidGoogleIdToken,
  type GoogleClaims,
  type GoogleIdTokenVerifier,
} from '../../application/ports/google-id-token-verifier';

const GOOGLE_JWKS_URL = new URL('https://www.googleapis.com/oauth2/v3/certs');

export class JoseGoogleIdTokenVerifier implements GoogleIdTokenVerifier {
  private readonly jwks = createRemoteJWKSet(GOOGLE_JWKS_URL);

  constructor(private readonly clientId: string) {}

  async verify(idToken: string): Promise<GoogleClaims> {
    let payload: JWTPayload;
    try {
      const result = await jwtVerify(idToken, this.jwks, {
        issuer: ['https://accounts.google.com', 'accounts.google.com'],
        audience: this.clientId,
      });
      payload = result.payload;
    } catch {
      throw new InvalidGoogleIdToken();
    }

    const sub = payload.sub;
    const email = payload['email'];
    const name = payload['name'];
    if (typeof sub !== 'string' || typeof email !== 'string') {
      throw new InvalidGoogleIdToken('Google ID token is missing required claims');
    }
    return {
      sub,
      email,
      name: typeof name === 'string' ? name : undefined,
    };
  }
}
