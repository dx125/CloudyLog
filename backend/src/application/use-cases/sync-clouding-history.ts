import type { CloudingRepository } from '../ports/clouding-repository';
import type { CloudingEntry } from '../../domain/clouding';

export interface HistoryEntryInput {
  day: string;
  count: number;
}

export class InvalidHistoryPayload extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'InvalidHistoryPayload';
  }
}

const DAY_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const MAX_ENTRIES_PER_SYNC = 4000;

/**
 * Bulk upload of on-device history (first Pro sign-in, or reconciliation
 * after being offline). Per-day merge keeps the larger count, so a sync can
 * only add progress, never erase it. Returns the full merged server history
 * for the client to pull back.
 */
export class SyncCloudingHistory {
  constructor(private readonly cloudings: CloudingRepository) {}

  async execute(
    userId: string,
    entries: HistoryEntryInput[],
  ): Promise<CloudingEntry[]> {
    if (entries.length > MAX_ENTRIES_PER_SYNC) {
      throw new InvalidHistoryPayload(
        `too many entries (max ${MAX_ENTRIES_PER_SYNC})`,
      );
    }
    for (const entry of entries) {
      if (!DAY_PATTERN.test(entry.day)) {
        throw new InvalidHistoryPayload(`invalid day: ${entry.day}`);
      }
      if (!Number.isInteger(entry.count) || entry.count < 0) {
        throw new InvalidHistoryPayload(`invalid count for ${entry.day}`);
      }
    }
    for (const entry of entries) {
      if (entry.count === 0) continue; // merge-max of 0 is a no-op
      await this.cloudings.mergeMaxForDay(userId, entry.day, entry.count);
    }
    return this.cloudings.getAllForUser(userId);
  }
}
