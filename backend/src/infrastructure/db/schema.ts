import {
  date,
  integer,
  jsonb,
  pgTable,
  primaryKey,
  text,
  timestamp,
  varchar,
} from 'drizzle-orm/pg-core';

export const users = pgTable('users', {
  id: text('id').primaryKey(),
  email: varchar('email', { length: 320 }).notNull().unique(),
  displayName: text('display_name').notNull(),
  passwordHash: text('password_hash'),
  country: varchar('country', { length: 2 }),
  createdAt: timestamp('created_at', { withTimezone: true })
    .defaultNow()
    .notNull(),
});

export const subscriptions = pgTable('subscriptions', {
  userId: text('user_id')
    .primaryKey()
    .references(() => users.id, { onDelete: 'cascade' }),
  status: text('status').notNull(),
  provider: text('provider').notNull(),
  startedAt: timestamp('started_at', { withTimezone: true }).notNull(),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  updatedAt: timestamp('updated_at', { withTimezone: true })
    .defaultNow()
    .notNull(),
});

export const authIdentities = pgTable(
  'auth_identities',
  {
    userId: text('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    provider: text('provider').notNull(),
    providerSubject: text('provider_subject').notNull(),
  },
  (t) => ({
    pk: primaryKey({ columns: [t.provider, t.providerSubject] }),
  }),
);

export const cloudingEntries = pgTable(
  'clouding_entries',
  {
    userId: text('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    day: date('day').notNull(),
    count: integer('count').notNull().default(0),
    updatedAt: timestamp('updated_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (t) => ({
    pk: primaryKey({ columns: [t.userId, t.day] }),
  }),
);

export const friendships = pgTable(
  'friendships',
  {
    requesterId: text('requester_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    addresseeId: text('addressee_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    status: text('status').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (t) => ({
    pk: primaryKey({ columns: [t.requesterId, t.addresseeId] }),
  }),
);

export const dailyAggregates = pgTable(
  'daily_aggregates',
  {
    day: date('day').notNull(),
    // '*' for the worldwide aggregate, else an ISO 3166-1 alpha-2 code.
    country: varchar('country', { length: 2 }).notNull(),
    totalUsers: integer('total_users').notNull(),
    p50: integer('p50').notNull(),
    p75: integer('p75').notNull(),
    p90: integer('p90').notNull(),
    distribution: jsonb('distribution').notNull(),
    computedAt: timestamp('computed_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (t) => ({
    pk: primaryKey({ columns: [t.day, t.country] }),
  }),
);
