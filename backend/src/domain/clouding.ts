export interface CloudingEntry {
  userId: string;
  day: string;
  count: number;
  updatedAt: Date;
}

/** Aggregate scope for worldwide comparisons (vs a 2-letter country code). */
export const WORLDWIDE_SCOPE = '*';

export interface DailyAggregate {
  day: string;
  /** WORLDWIDE_SCOPE for the global aggregate, else ISO country code. */
  country: string;
  totalUsers: number;
  p50: number;
  p75: number;
  p90: number;
  distribution: Record<string, number>;
}
