-- =============================================================================
-- Puff — events (the cloud mirror of the on-device append-only event log).
--
-- Offline-first: the device's Drift store is the source of truth; this table
-- is a sync target and the input to global aggregates. Client-generated
-- UUIDv7 ids make sync idempotent (upsert; last-write-wins is fine because
-- events are effectively immutable — only `tags` can change, within the app's
-- 10-second quick-tag window).
--
-- Meals are a second event `type`, not a separate system (food detective,
-- Phase 2 — the check constraint already admits them).
--
-- RLS: users read/write only their own rows. Cloud storage is a Pro feature,
-- so INSERT/UPDATE additionally require an active entitlement — a free-tier
-- client has nothing it may write. SELECT and DELETE stay entitlement-free:
-- a lapsed subscriber can still read (and erase) what they already stored.
-- =============================================================================

create table if not exists events (
  id          uuid primary key,
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  type        text not null default 'toot' check (type in ('toot', 'meal')),
  occurred_at timestamptz not null,
  tags        text[] not null default '{}',
  device_id   text not null default '',
  received_at timestamptz not null default now()
);

create index if not exists events_user_occurred_idx
  on events (user_id, occurred_at desc);

alter table events enable row level security;

create policy "events: read own"
  on events for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy "events: pro insert own"
  on events for insert
  to authenticated
  with check (user_id = (select auth.uid()) and has_active_pro());

create policy "events: pro update own"
  on events for update
  to authenticated
  using (user_id = (select auth.uid()) and has_active_pro())
  with check (user_id = (select auth.uid()) and has_active_pro());

create policy "events: delete own"
  on events for delete
  to authenticated
  using (user_id = (select auth.uid()));
