export interface CloudingEntry {
  userId: string;
  day: string;
  count: number;
  updatedAt: Date;
}

export interface DailyAggregate {
  day: string;
  totalUsers: number;
  p50: number;
  p75: number;
  p90: number;
  distribution: Record<string, number>;
}
