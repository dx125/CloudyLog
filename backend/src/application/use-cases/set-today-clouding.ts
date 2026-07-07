import type { Clock } from '../ports/clock';
import type { CloudingRepository } from '../ports/clouding-repository';
import type { CloudingEntry } from '../../domain/clouding';

/**
 * Absolute write of today's count. The device is the source of truth for the
 * signed-in user's own taps, so pushes (including reset-to-zero) overwrite
 * rather than merge.
 */
export class SetTodayClouding {
  constructor(
    private readonly cloudings: CloudingRepository,
    private readonly clock: Clock,
  ) {}

  async execute(userId: string, count: number): Promise<CloudingEntry> {
    if (!Number.isInteger(count) || count < 0) {
      throw new Error('count must be a non-negative integer');
    }
    return this.cloudings.setForDay(userId, this.clock.today(), count);
  }
}
