import type { SubscriptionProvider } from '../../domain/subscription';

export interface PurchaseValidation {
  provider: SubscriptionProvider;
  expiresAt: Date;
}

/**
 * Verifies a purchase receipt with the billing provider and returns the
 * entitlement window it grants. The mock implementation accepts any receipt;
 * Google Play / App Store validators implement the same port later.
 */
export interface PurchaseValidator {
  validate(
    userId: string,
    provider: string,
    receipt: string,
  ): Promise<PurchaseValidation>;
}

export class InvalidPurchase extends Error {
  constructor(message = 'Purchase could not be validated') {
    super(message);
    this.name = 'InvalidPurchase';
  }
}
