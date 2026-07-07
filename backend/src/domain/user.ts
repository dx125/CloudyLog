export type AuthProvider = 'credentials' | 'google';

export interface User {
  id: string;
  email: string;
  displayName: string;
  /** ISO 3166-1 alpha-2, uppercase. Null until the user provides one. */
  country: string | null;
  createdAt: Date;
}

export function isValidCountryCode(value: string): boolean {
  return /^[A-Z]{2}$/.test(value);
}

export interface UserIdentity {
  userId: string;
  provider: AuthProvider;
  providerSubject: string;
}
