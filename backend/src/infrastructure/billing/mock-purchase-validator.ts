import type { Clock } from '../../application/ports/clock';
import {
  InvalidPurchase,
  type PurchaseValidation,
  type PurchaseValidator,
} from '../../application/ports/purchase-validator';

const MOCK_ENTITLEMENT_DAYS = 30;

/**
 * Development-only billing: accepts any non-empty receipt for the 'mock'
 * provider and grants 30 days of Pro. Replace (or complement) with
 * GooglePlayPurchaseValidator / AppStorePurchaseValidator in composition.ts
 * when store billing lands — routes and use cases stay unchanged.
 */
export class MockPurchaseValidator implements PurchaseValidator {
  constructor(private readonly clock: Clock) {}

  async validate(
    _userId: string,
    provider: string,
    receipt: string,
  ): Promise<PurchaseValidation> {
    if (provider !== 'mock') {
      throw new InvalidPurchase(`provider '${provider}' is not supported yet`);
    }
    if (!receipt.trim()) {
      throw new InvalidPurchase('receipt must not be empty');
    }
    const expiresAt = new Date(this.clock.now());
    expiresAt.setUTCDate(expiresAt.getUTCDate() + MOCK_ENTITLEMENT_DAYS);
    return { provider: 'mock', expiresAt };
  }
}
