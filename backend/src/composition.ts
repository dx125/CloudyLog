import type { TokenIssuer } from './application/ports/token-issuer';
import { ActivateSubscription } from './application/use-cases/activate-subscription';
import { CancelSubscription } from './application/use-cases/cancel-subscription';
import { GetCloudingHistory } from './application/use-cases/get-clouding-history';
import { GetMyProfile } from './application/use-cases/get-my-profile';
import { GetSubscriptionStatus } from './application/use-cases/get-subscription-status';
import { GetTodayStats } from './application/use-cases/get-today-stats';
import { ListFriendsToday } from './application/use-cases/list-friends-today';
import { ListPendingFriendRequests } from './application/use-cases/list-pending-friend-requests';
import { RecordClouding } from './application/use-cases/record-clouding';
import { RespondToFriendRequest } from './application/use-cases/respond-to-friend-request';
import { RunDailyAggregate } from './application/use-cases/run-daily-aggregate';
import { SendFriendRequest } from './application/use-cases/send-friend-request';
import { SetTodayClouding } from './application/use-cases/set-today-clouding';
import { SignInWithCredentials } from './application/use-cases/sign-in-credentials';
import { SignInWithGoogle } from './application/use-cases/sign-in-google';
import { SignUpWithCredentials } from './application/use-cases/sign-up-credentials';
import { SyncCloudingHistory } from './application/use-cases/sync-clouding-history';
import { UpdateMyProfile } from './application/use-cases/update-my-profile';
import type { Env } from './env';
import { JoseGoogleIdTokenVerifier } from './infrastructure/auth/jose-google-id-token-verifier';
import { JwtTokenIssuer } from './infrastructure/auth/jwt-token-issuer';
import { Pbkdf2PasswordHasher } from './infrastructure/auth/pbkdf2-password-hasher';
import { MockPurchaseValidator } from './infrastructure/billing/mock-purchase-validator';
import { SystemClock } from './infrastructure/clock/system-clock';
import { createDb } from './infrastructure/db/client';
import { DrizzleCloudingRepository } from './infrastructure/db/drizzle-clouding-repository';
import { DrizzleFriendshipRepository } from './infrastructure/db/drizzle-friendship-repository';
import { DrizzleSubscriptionRepository } from './infrastructure/db/drizzle-subscription-repository';
import { DrizzleUserRepository } from './infrastructure/db/drizzle-user-repository';

/**
 * Consumers depend only on ports. Swapping the JWT issuer for an opaque-token
 * issuer (for example) is a single change here — routes and middleware are
 * unaffected. Likewise, real store billing replaces MockPurchaseValidator
 * here without touching routes or use cases.
 */
export interface Container {
  tokens: TokenIssuer;
  signUpWithCredentials: SignUpWithCredentials;
  signInWithCredentials: SignInWithCredentials;
  signInWithGoogle: SignInWithGoogle;
  getMyProfile: GetMyProfile;
  updateMyProfile: UpdateMyProfile;
  getSubscriptionStatus: GetSubscriptionStatus;
  activateSubscription: ActivateSubscription;
  cancelSubscription: CancelSubscription;
  recordClouding: RecordClouding;
  setTodayClouding: SetTodayClouding;
  getCloudingHistory: GetCloudingHistory;
  syncCloudingHistory: SyncCloudingHistory;
  getTodayStats: GetTodayStats;
  sendFriendRequest: SendFriendRequest;
  respondToFriendRequest: RespondToFriendRequest;
  listPendingFriendRequests: ListPendingFriendRequests;
  listFriendsToday: ListFriendsToday;
  runDailyAggregate: RunDailyAggregate;
}

export function buildContainer(env: Env): Container {
  const db = createDb(env.DATABASE_URL);
  const users = new DrizzleUserRepository(db);
  const cloudings = new DrizzleCloudingRepository(db);
  const friendships = new DrizzleFriendshipRepository(db);
  const subscriptions = new DrizzleSubscriptionRepository(db);
  const clock = new SystemClock();
  const hasher = new Pbkdf2PasswordHasher();
  const tokens: TokenIssuer = new JwtTokenIssuer(env.JWT_SECRET);
  const googleVerifier = new JoseGoogleIdTokenVerifier(env.GOOGLE_CLIENT_ID);
  const purchaseValidator = new MockPurchaseValidator(clock);

  const getSubscriptionStatus = new GetSubscriptionStatus(
    subscriptions,
    clock,
  );

  return {
    tokens,
    signUpWithCredentials: new SignUpWithCredentials(users, hasher, tokens),
    signInWithCredentials: new SignInWithCredentials(users, hasher, tokens),
    signInWithGoogle: new SignInWithGoogle(users, googleVerifier, tokens),
    getMyProfile: new GetMyProfile(users, getSubscriptionStatus),
    updateMyProfile: new UpdateMyProfile(users),
    getSubscriptionStatus,
    activateSubscription: new ActivateSubscription(
      subscriptions,
      purchaseValidator,
      clock,
    ),
    cancelSubscription: new CancelSubscription(subscriptions, clock),
    recordClouding: new RecordClouding(cloudings, clock),
    setTodayClouding: new SetTodayClouding(cloudings, clock),
    getCloudingHistory: new GetCloudingHistory(cloudings),
    syncCloudingHistory: new SyncCloudingHistory(cloudings),
    getTodayStats: new GetTodayStats(cloudings, users, clock),
    sendFriendRequest: new SendFriendRequest(friendships, users),
    respondToFriendRequest: new RespondToFriendRequest(friendships),
    listPendingFriendRequests: new ListPendingFriendRequests(
      friendships,
      users,
    ),
    listFriendsToday: new ListFriendsToday(friendships, cloudings, users, clock),
    runDailyAggregate: new RunDailyAggregate(cloudings, clock),
  };
}
