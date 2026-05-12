import type { Clock } from '../ports/clock';
import type { CloudingRepository } from '../ports/clouding-repository';
import { percentileRankFor } from '../../domain/percentile';

export interface TodayStats {
  day: string;
  count: number;
  percentile: number | null;
  totalUsers: number | null;
}

export class GetTodayStats {
  constructor(
    private readonly cloudings: CloudingRepository,
    private readonly clock: Clock,
  ) {}

  async execute(userId: string): Promise<TodayStats> {
    const day = this.clock.today();
    const [entry, aggregate] = await Promise.all([
      this.cloudings.getForDay(userId, day),
      this.cloudings.getAggregate(day),
    ]);
    const count = entry?.count ?? 0;
    if (!aggregate || aggregate.totalUsers === 0) {
      return {
        day,
        count,
        percentile: null,
        totalUsers: aggregate?.totalUsers ?? null,
      };
    }
    return {
      day,
      count,
      percentile: percentileRankFor(count, aggregate.distribution),
      totalUsers: aggregate.totalUsers,
    };
  }
}
