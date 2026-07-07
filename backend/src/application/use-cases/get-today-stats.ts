import type { Clock } from '../ports/clock';
import type { CloudingRepository } from '../ports/clouding-repository';
import type { UserRepository } from '../ports/user-repository';
import { WORLDWIDE_SCOPE } from '../../domain/clouding';
import { percentileRankFor } from '../../domain/percentile';

export type StatsScope = 'worldwide' | 'country';

export class CountryNotSet extends Error {
  constructor() {
    super('User has no country set');
    this.name = 'CountryNotSet';
  }
}

export interface TodayStats {
  day: string;
  scope: StatsScope;
  /** Country the stats were computed against; null for worldwide. */
  country: string | null;
  count: number;
  percentile: number | null;
  totalUsers: number | null;
}

export class GetTodayStats {
  constructor(
    private readonly cloudings: CloudingRepository,
    private readonly users: UserRepository,
    private readonly clock: Clock,
  ) {}

  async execute(
    userId: string,
    scope: StatsScope = 'worldwide',
  ): Promise<TodayStats> {
    const day = this.clock.today();
    let aggregateCountry = WORLDWIDE_SCOPE;
    let country: string | null = null;
    if (scope === 'country') {
      const user = await this.users.findById(userId);
      if (!user?.country) throw new CountryNotSet();
      country = user.country;
      aggregateCountry = user.country;
    }
    const [entry, aggregate] = await Promise.all([
      this.cloudings.getForDay(userId, day),
      this.cloudings.getAggregate(day, aggregateCountry),
    ]);
    const count = entry?.count ?? 0;
    if (!aggregate || aggregate.totalUsers === 0) {
      return {
        day,
        scope,
        country,
        count,
        percentile: null,
        totalUsers: aggregate?.totalUsers ?? null,
      };
    }
    return {
      day,
      scope,
      country,
      count,
      percentile: percentileRankFor(count, aggregate.distribution),
      totalUsers: aggregate.totalUsers,
    };
  }
}
