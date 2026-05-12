import type { CloudingEntry, DailyAggregate } from '../../domain/clouding';

export interface CloudingRepository {
  getForDay(userId: string, day: string): Promise<CloudingEntry | null>;
  incrementForDay(
    userId: string,
    day: string,
    delta: number,
  ): Promise<CloudingEntry>;
  setForDay(
    userId: string,
    day: string,
    count: number,
  ): Promise<CloudingEntry>;
  getCountsForUsers(
    userIds: string[],
    day: string,
  ): Promise<Map<string, number>>;
  computeDailyAggregate(day: string): Promise<DailyAggregate>;
  saveAggregate(aggregate: DailyAggregate): Promise<void>;
  getAggregate(day: string): Promise<DailyAggregate | null>;
}
