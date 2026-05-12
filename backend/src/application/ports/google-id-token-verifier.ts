export interface GoogleClaims {
  sub: string;
  email: string;
  name?: string;
}

export interface GoogleIdTokenVerifier {
  verify(idToken: string): Promise<GoogleClaims>;
}

export class InvalidGoogleIdToken extends Error {
  constructor(message = 'Invalid Google ID token') {
    super(message);
    this.name = 'InvalidGoogleIdToken';
  }
}
