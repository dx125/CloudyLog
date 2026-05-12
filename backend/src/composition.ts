import type { TokenIssuer } from './application/ports/token-issuer';
import { GetTodayStats } from './application/use-cases/get-today-stats';
import { ListFriendsToday } from './application/use-cases/list-friends-today';
import { RecordClouding } from './application/use-cases/record-clouding';
import { RespondToFriendRequest } from './application/use-cases/respond-to-friend-request';
import { RunDailyAggregate } from './application/use-cases/run-daily-aggregate';
import { SendFriendRequest } from './application/use-cases/send-friend-request';
import { SignInWithCredentials } from './application/use-cases/sign-in-credentials';
import { SignInWithGoogle } from './application/use-cases/sign-in-google';
import { SignUpWithCredentials } from './application/use-cases/sign-up-credentials';
import type { Env } from './env';
import { JoseGoogleIdTokenVerifier } from './infrastructure/auth/jose-google-id-token-verifier';
import { JwtTokenIssuer } from './infrastructure/auth/jwt-token-issuer';
import { Pbkdf2PasswordHasher } from './infrastructure/auth/pbkdf2-password-hasher';
import { SystemClock } from './infrastructure/clock/system-clock';
import { createDb } from './infrastructure/db/client';
import { DrizzleCloudingRepository } from './infrastructure/db/drizzle-clouding-repository';
import { DrizzleFriendshipRepository } from './infrastructure/db/drizzle-friendship-repository';
import { DrizzleUserRepository } from './infrastructure/db/drizzle-user-repository';

/**
 * Consumers depend only on ports. Swapping the JWT issuer for an opaque-token
 * issuer (for example) is a single change here — routes and middleware are
 * unaffected.
 */
export interface Container {
  tokens: TokenIssuer;
  signUpWithCredentials: SignUpWithCredentials;
  signInWithCredentials: SignInWithCredentials;
  signInWithGoogle: SignInWithGoogle;
  recordClouding: RecordClouding;
  getTodayStats: GetTodayStats;
  sendFriendRequest: SendFriendRequest;
  respondToFriendRequest: RespondToFriendRequest;
  listFriendsToday: ListFriendsToday;
  runDailyAggregate: RunDailyAggregate;
}

export function buildContainer(env: Env): Container {
  const db = createDb(env.DATABASE_URL);
  const users = new DrizzleUserRepository(db);
  const cloudings = new DrizzleCloudingRepository(db);
  const friendships = new DrizzleFriendshipRepository(db);
  const clock = new SystemClock();
  const hasher = new Pbkdf2PasswordHasher();
  const tokens: TokenIssuer = new JwtTokenIssuer(env.JWT_SECRET);
  const googleVerifier = new JoseGoogleIdTokenVerifier(env.GOOGLE_CLIENT_ID);

  return {
    tokens,
    signUpWithCredentials: new SignUpWithCredentials(users, hasher, tokens),
    signInWithCredentials: new SignInWithCredentials(users, hasher, tokens),
    signInWithGoogle: new SignInWithGoogle(users, googleVerifier, tokens),
    recordClouding: new RecordClouding(cloudings, clock),
    getTodayStats: new GetTodayStats(cloudings, clock),
    sendFriendRequest: new SendFriendRequest(friendships, users),
    respondToFriendRequest: new RespondToFriendRequest(friendships),
    listFriendsToday: new ListFriendsToday(friendships, cloudings, users, clock),
    runDailyAggregate: new RunDailyAggregate(cloudings, clock),
  };
}
