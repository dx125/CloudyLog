-- =============================================================================
-- Puff — duels (head-to-head weeks, and live 3-minute rounds).
--
-- Two kinds share one table because they differ only in window length and
-- which score column counts:
--   'async' — the real competition. Scores tapped events over days. This is
--             the retention mechanic: a reason to open the app tomorrow.
--   'live'  — party mode. Scores heard events over minutes, both phones in
--             Listen mode. Explicitly honour-system: a mouth raspberry beats
--             any classifier we can ship, so the anti-cheat here is social
--             (you're in the same room) rather than technical. Never promise
--             verification we can't deliver.
--
-- NAMES ARE NOT FREE TEXT — and that is the point.
-- `name_adj` / `name_noun` / `handle` are indices into a curated word list the
-- client renders ("Breezy Badgers"). TODO.md lists a profanity filter and a
-- report flow as a hard blocker before any social feature ships; storing
-- indices *deletes* that blocker rather than mitigating it. There is no column
-- a slur can go in, so there is no filter to bypass, no moderation queue, and
-- no store-review exposure. It is also funnier than what users would type.
-- If custom names ever ship as a Pro cosmetic, that's when a filter + report
-- flow gets built — not before.
--
-- SCORES ARE SUBMITTED, NOT DERIVED.
-- The server has no raw events for free users (only `user_daily_stats`, one
-- number per day), so a duel score can't be computed server-side. Clients
-- submit; the edge function validates plausibility and enforces monotonicity.
-- This doesn't violate the append-only rule — that governs the *event log*,
-- which remains the only source of truth on the device.
--
-- RLS: membership is the whole access model. You see a duel only if you're in
-- it. Creating is Pro-gated in the policy itself (joining stays free — the
-- invited person is the acquisition, per the handoff).
-- =============================================================================

create table if not exists duels (
  id         uuid primary key default gen_random_uuid(),
  -- 6 chars from an unambiguous alphabet (no I/O/0/1). Shared as text over any
  -- chat app, so no deep-link infrastructure is needed to invite someone.
  code       text not null unique check (code ~ '^[A-HJ-NP-Z2-9]{6}$'),
  kind       text not null check (kind in ('async', 'live')),
  name_adj   smallint not null check (name_adj >= 0),
  name_noun  smallint not null check (name_noun >= 0),
  created_by uuid not null default auth.uid() references auth.users(id) on delete cascade,
  starts_at  timestamptz not null,
  ends_at    timestamptz not null,
  status     text not null default 'open' check (status in ('open', 'running', 'settled')),
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create index if not exists duels_code_idx on duels (code);
create index if not exists duels_creator_idx on duels (created_by, created_at desc);

create table if not exists duel_members (
  duel_id   uuid not null references duels(id) on delete cascade,
  user_id   uuid not null default auth.uid() references auth.users(id) on delete cascade,
  handle    smallint not null check (handle >= 0),
  joined_at timestamptz not null default now(),
  primary key (duel_id, user_id)
);

create index if not exists duel_members_user_idx on duel_members (user_id);

create table if not exists duel_scores (
  duel_id    uuid not null references duels(id) on delete cascade,
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  -- Kept apart for the same reason events are: an async duel scores taps, a
  -- live duel scores heard events, and the two must never be added together.
  tapped     int not null default 0 check (tapped >= 0),
  heard      int not null default 0 check (heard >= 0),
  updated_at timestamptz not null default now(),
  primary key (duel_id, user_id)
);

-- Membership predicate — the whole access model, so everything else depends on
-- it. Declared *after* the tables: `language sql` bodies are validated at
-- creation time, so defining this first fails with "relation duel_members does
-- not exist".
--
-- SECURITY DEFINER so the duels/duel_scores policies can consult duel_members
-- without recursing through duel_members' own RLS.
create or replace function is_duel_member(d uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from duel_members
    where duel_id = d and user_id = (select auth.uid())
  );
$$;

alter table duels enable row level security;
alter table duel_members enable row level security;
alter table duel_scores enable row level security;

-- duels ---------------------------------------------------------------------
create policy "duels: members read"
  on duels for select
  to authenticated
  using (is_duel_member(id));

-- Creating a duel is the Pro capability, enforced in Postgres rather than the
-- client. Joining one (below) is free.
create policy "duels: pro create own"
  on duels for insert
  to authenticated
  with check (created_by = (select auth.uid()) and has_active_pro());

create policy "duels: creator updates"
  on duels for update
  to authenticated
  using (created_by = (select auth.uid()))
  with check (created_by = (select auth.uid()));

-- duel_members --------------------------------------------------------------
create policy "duel_members: members read"
  on duel_members for select
  to authenticated
  using (is_duel_member(duel_id));

create policy "duel_members: join as self"
  on duel_members for insert
  to authenticated
  with check (user_id = (select auth.uid()));

create policy "duel_members: leave own"
  on duel_members for delete
  to authenticated
  using (user_id = (select auth.uid()));

-- duel_scores ---------------------------------------------------------------
-- Everyone in the duel reads every score (that's the leaderboard); you may only
-- write your own row.
create policy "duel_scores: members read"
  on duel_scores for select
  to authenticated
  using (is_duel_member(duel_id));

create policy "duel_scores: write own"
  on duel_scores for insert
  to authenticated
  with check (user_id = (select auth.uid()) and is_duel_member(duel_id));

create policy "duel_scores: update own"
  on duel_scores for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- Grants (see 0006: RLS picks rows, GRANT decides table access, and GRANT is
-- checked first).
grant select, insert, update on duels to authenticated;
grant select, insert, delete on duel_members to authenticated;
grant select, insert, update on duel_scores to authenticated;
grant execute on function is_duel_member(uuid) to authenticated;
