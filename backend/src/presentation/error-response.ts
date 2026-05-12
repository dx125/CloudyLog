import type { Context } from 'hono';

import { InvalidGoogleIdToken } from '../application/ports/google-id-token-verifier';
import {
  FriendRequestNotFound,
  FriendRequestNotPending,
} from '../application/use-cases/respond-to-friend-request';
import {
  CannotBefriendSelf,
  UserNotFound,
} from '../application/use-cases/send-friend-request';
import { InvalidCredentials } from '../application/use-cases/sign-in-credentials';
import { AccountLinkingRequired } from '../application/use-cases/sign-in-google';
import { EmailAlreadyRegistered } from '../application/use-cases/sign-up-credentials';

export function toErrorResponse(err: unknown, c: Context): Response {
  if (err instanceof InvalidCredentials) {
    return c.json({ error: 'invalid_credentials' }, 401);
  }
  if (err instanceof EmailAlreadyRegistered) {
    return c.json({ error: 'email_already_registered' }, 409);
  }
  if (err instanceof AccountLinkingRequired) {
    return c.json({ error: 'account_linking_required' }, 409);
  }
  if (err instanceof InvalidGoogleIdToken) {
    return c.json({ error: 'invalid_google_token' }, 401);
  }
  if (err instanceof UserNotFound) {
    return c.json({ error: 'user_not_found' }, 404);
  }
  if (err instanceof CannotBefriendSelf) {
    return c.json({ error: 'cannot_befriend_self' }, 400);
  }
  if (err instanceof FriendRequestNotFound) {
    return c.json({ error: 'friend_request_not_found' }, 404);
  }
  if (err instanceof FriendRequestNotPending) {
    return c.json({ error: 'friend_request_not_pending' }, 409);
  }
  console.error(err);
  return c.json({ error: 'internal_error' }, 500);
}
