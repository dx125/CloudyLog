export type AuthProvider = 'credentials' | 'google';

export interface User {
  id: string;
  email: string;
  displayName: string;
  createdAt: Date;
}

export interface UserIdentity {
  userId: string;
  provider: AuthProvider;
  providerSubject: string;
}
