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
  /** Upsert keeping the larger of the stored and provided count. Used by
   * history sync so an upload can never lose server-side progress. */
  mergeMaxForDay(
    userId: string,
    day: string,
    count: number,
  ): Promise<CloudingEntry>;
  getAllForUser(userId: string): Promise<CloudingEntry[]>;
  getCountsForUsers(
    userIds: string[],
    day: string,
  ): Promise<Map<string, number>>;
  /** Computes the worldwide aggregate plus one aggregate per country that has
   * at least one entry for the day. */
  computeDailyAggregates(day: string): Promise<DailyAggregate[]>;
  saveAggregate(aggregate: DailyAggregate): Promise<void>;
  getAggregate(day: string, country: string): Promise<DailyAggregate | null>;
}
