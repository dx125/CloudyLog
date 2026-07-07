import { describe, expect, test } from 'vitest';

import { CountryNotSet, GetTodayStats } from './get-today-stats';
import {
  FixedClock,
  InMemoryCloudingRepository,
  InMemoryUserRepository,
  WORLDWIDE_SCOPE,
} from './fakes.test-helpers';

const NOW = new Date('2026-07-06T12:00:00Z');
const TODAY = '2026-07-06';

async function setup() {
  const clock = new FixedClock(NOW);
  const cloudings = new InMemoryCloudingRepository();
  const users = new InMemoryUserRepository();
  const user = await users.create({
    email: 'a@b.c',
    displayName: 'A',
    country: 'UY',
  });
  await cloudings.setForDay(user.id, TODAY, 20);
  return {
    userId: user.id,
    users,
    cloudings,
    stats: new GetTodayStats(cloudings, users, clock),
  };
}

describe('GetTodayStats', () => {
  test('worldwide scope reads the worldwide aggregate', async () => {
    const { stats, cloudings, userId } = await setup();
    cloudings.seedAggregate(TODAY, WORLDWIDE_SCOPE, { '10': 4, '20': 4, '30': 2 });

    const result = await stats.execute(userId, 'worldwide');
    expect(result.scope).toBe('worldwide');
    expect(result.country).toBeNull();
    expect(result.count).toBe(20);
    expect(result.totalUsers).toBe(10);
    expect(result.percentile).toBe(60);
  });

  test('country scope reads the user country aggregate', async () => {
    const { stats, cloudings, userId } = await setup();
    cloudings.seedAggregate(TODAY, 'UY', { '10': 1, '20': 1 });

    const result = await stats.execute(userId, 'country');
    expect(result.scope).toBe('country');
    expect(result.country).toBe('UY');
    expect(result.totalUsers).toBe(2);
  });

  test('country scope without a country fails', async () => {
    const { stats, users, userId } = await setup();
    await users.updateProfile(userId, { country: null });

    await expect(stats.execute(userId, 'country')).rejects.toThrow(
      CountryNotSet,
    );
  });

  test('missing aggregate yields null percentile', async () => {
    const { stats, userId } = await setup();
    const result = await stats.execute(userId, 'worldwide');
    expect(result.percentile).toBeNull();
    expect(result.totalUsers).toBeNull();
    expect(result.count).toBe(20);
  });
});
