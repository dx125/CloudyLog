import type { Clock } from '../ports/clock';
import type { CloudingRepository } from '../ports/clouding-repository';

export class RunDailyAggregate {
  constructor(
    private readonly cloudings: CloudingRepository,
    private readonly clock: Clock,
  ) {}

  async execute(day?: string): Promise<void> {
    const targetDay = day ?? this.clock.today();
    const aggregates = await this.cloudings.computeDailyAggregates(targetDay);
    for (const aggregate of aggregates) {
      await this.cloudings.saveAggregate(aggregate);
    }
  }
}
