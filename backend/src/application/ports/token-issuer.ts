export interface TokenIssuer {
  issue(userId: string): Promise<string>;
  verify(token: string): Promise<{ userId: string } | null>;
}
