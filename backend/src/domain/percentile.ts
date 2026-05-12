/**
 * Midpoint percentile rank: for a distribution of counts, returns how "high"
 * `count` scores as a percentage (0-100). Ties contribute half their mass so
 * "everyone tied at top" maps to 50 — more honest than the strict-below or
 * inclusive-at-or-below variants.
 */
export function percentileRankFor(
  count: number,
  distribution: Record<string, number>,
): number {
  let total = 0;
  let below = 0;
  let equal = 0;
  for (const [bucketRaw, n] of Object.entries(distribution)) {
    const bucket = Number(bucketRaw);
    if (!Number.isFinite(bucket) || n <= 0) continue;
    total += n;
    if (bucket < count) below += n;
    else if (bucket === count) equal += n;
  }
  if (total === 0) return 0;
  return Math.round(((below + equal / 2) / total) * 100);
}
