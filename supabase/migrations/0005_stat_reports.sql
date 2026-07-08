-- =============================================================================
-- Puff — per-user daily stat reports (the free tier's stake in world stats).
--
-- Raw event sync stays Pro-only (0003), but the world histogram needs
-- everyone. So each client — free or Pro — reports at most one row per day:
-- (day, toot_count), nothing else. `day` is the *client's local* date: a
-- "day" in the histogram means the user's day, not a UTC slice.
--
-- 0004's aggregates now compute from these reports instead of raw events:
-- cheaper (no event scans — the rollup TODO.md wanted anyway) and covering
-- the whole population instead of only Pro subscribers.
-- =============================================================================

create table if not exists user_daily_stats (
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day         date not null,
  -- Sanity ceiling against poisoned aggregates; the client clamps to the same
  -- bound. Same idea the duels anti-cheat will need later (TODO.md).
  toot_count  int not null check (toot_count between 1 and 1000),
  reported_at timestamptz not null default now(),
  primary key (user_id, day)
);

alter table user_daily_stats enable row level security;

-- Own-row and entitlement-free: contributing to the world histogram is not a
-- Pro feature (contrast events, where insert/update require has_active_pro()).
create policy "user daily stats: read own"
  on user_daily_stats for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy "user daily stats: insert own"
  on user_daily_stats for insert
  to authenticated
  with check (user_id = (select auth.uid()));

create policy "user daily stats: update own"
  on user_daily_stats for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "user daily stats: delete own"
  on user_daily_stats for delete
  to authenticated
  using (user_id = (select auth.uid()));

-- Replaces 0004's version: aggregate from the daily reports, not raw events.
-- `create or replace` keeps the ACLs from 0004, so this stays cron/service-
-- only — never client-callable.
create or replace function compute_daily_global_stats(target_day date)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  with per_user as (
    select user_id, toot_count as n
    from user_daily_stats
    where day = target_day
  ),
  buckets as (
    select n, count(*)::int as users from per_user group by n
  ),
  agg as (
    select
      coalesce((select count(*) from per_user), 0)::int as total_users,
      coalesce((select percentile_cont(0.5) within group (order by n) from per_user), 0)::int as p50,
      coalesce((select percentile_cont(0.75) within group (order by n) from per_user), 0)::int as p75,
      coalesce((select percentile_cont(0.9) within group (order by n) from per_user), 0)::int as p90,
      coalesce((select jsonb_object_agg(n::text, users) from buckets), '{}'::jsonb) as distribution
  )
  insert into daily_global_stats (day, total_users, p50, p75, p90, distribution, computed_at)
  select target_day, total_users, p50, p75, p90, distribution, now() from agg
  on conflict (day) do update
    set total_users = excluded.total_users,
        p50 = excluded.p50,
        p75 = excluded.p75,
        p90 = excluded.p90,
        distribution = excluded.distribution,
        computed_at = now();
end;
$$;

-- refresh_global_stats() and its pg_cron schedule (0004) are unchanged: they
-- still recompute the current UTC day and the previous one, which absorbs
-- late reports from every timezone within a day.
