import { describe, expect, test } from 'vitest';

import { percentileRankFor } from './percentile';

describe('percentileRankFor', () => {
  test('returns 0 for an empty distribution', () => {
    expect(percentileRankFor(10, {})).toBe(0);
  });

  test('strict top scores 100', () => {
    // user has 50; everyone else has 10 or 20
    const distribution = { '10': 5, '20': 5, '50': 1 };
    expect(percentileRankFor(50, distribution)).toBe(95);
  });

  test('strict bottom scores 0 when nobody is below', () => {
    // user has 0; nobody is below them
    const distribution = { '0': 1, '10': 5, '20': 5 };
    expect(percentileRankFor(0, distribution)).toBe(5); // half of own bucket
  });

  test('all-tied users land at midpoint (~50)', () => {
    // everyone tied at 35 → user is in the middle of the equal bucket
    const distribution = { '35': 100 };
    expect(percentileRankFor(35, distribution)).toBe(50);
  });

  test('scores within a known mixed distribution', () => {
    // 4 users at 0, 4 at 10, 2 at 20  (total 10)
    // user with count 10: below = 4, equal = 4, total = 10
    // → (4 + 2) / 10 = 60
    const distribution = { '0': 4, '10': 4, '20': 2 };
    expect(percentileRankFor(10, distribution)).toBe(60);
  });

  test('ignores non-numeric or zero-count buckets', () => {
    const distribution = { '10': 5, foo: 99 } as Record<string, number>;
    expect(percentileRankFor(10, distribution)).toBe(50);
  });
});
