import type {
  UserProfilePatch,
  UserRepository,
} from '../ports/user-repository';
import { isValidCountryCode, type User } from '../../domain/user';

export class InvalidProfilePatch extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'InvalidProfilePatch';
  }
}

export class UpdateMyProfile {
  constructor(private readonly users: UserRepository) {}

  async execute(userId: string, patch: UserProfilePatch): Promise<User> {
    const normalized: UserProfilePatch = {};
    if (patch.displayName !== undefined) {
      const trimmed = patch.displayName.trim();
      if (!trimmed) {
        throw new InvalidProfilePatch('displayName must not be empty');
      }
      normalized.displayName = trimmed;
    }
    if (patch.country !== undefined) {
      if (patch.country === null) {
        normalized.country = null;
      } else {
        const code = patch.country.trim().toUpperCase();
        if (!isValidCountryCode(code)) {
          throw new InvalidProfilePatch(
            'country must be a 2-letter ISO 3166-1 code',
          );
        }
        normalized.country = code;
      }
    }
    return this.users.updateProfile(userId, normalized);
  }
}
