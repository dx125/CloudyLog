import type { Clock } from '../ports/clock';
import type { CloudingRepository } from '../ports/clouding-repository';
import type { CloudingEntry } from '../../domain/clouding';

export class RecordClouding {
  constructor(
    private readonly cloudings: CloudingRepository,
    private readonly clock: Clock,
  ) {}

  async execute(userId: string, delta = 1): Promise<CloudingEntry> {
    if (delta <= 0) {
      throw new Error('delta must be positive');
    }
    return this.cloudings.incrementForDay(userId, this.clock.today(), delta);
  }
}
