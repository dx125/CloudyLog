-- =============================================================================
-- Puff — anonymous global aggregates.
--
-- A pg_cron job rolls synced events into daily_global_stats; clients read
-- aggregates only — never raw population data (performance and privacy).
-- The distribution is a jsonb histogram {"<count>": <users>} from which the
-- app computes a midpoint percentile rank locally.
--
-- Day boundaries are UTC. The cron runs daily at 03:10 UTC and recomputes
-- both today-so-far and yesterday (to absorb late syncs); move to hourly when
-- volume justifies it (see Documentation/TODO.md).
-- =============================================================================

create table if not exists daily_global_stats (
  day         date primary key,
  total_users int not null,
  p50         int not null,
  p75         int not null,
  p90         int not null,
  distribution jsonb not null,
  computed_at timestamptz not null default now()
);

alter table daily_global_stats enable row level security;

-- Read-only for signed-in clients (anonymous sessions carry the
-- `authenticated` role too). No write policies: only definer functions write.
create policy "global stats: read"
  on daily_global_stats for select
  to authenticated
  using (true);

create or replace function compute_daily_global_stats(target_day date)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  day_start timestamptz := target_day::timestamp at time zone 'utc';
begin
  with per_user as (
    select user_id, count(*)::int as n
    from events
    where type = 'toot'
      and occurred_at >= day_start
      and occurred_at < day_start + interval '1 day'
    group by user_id
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

-- Cron entry point: refresh the current UTC day and the previous one.
create or replace function refresh_global_stats()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform compute_daily_global_stats((now() at time zone 'utc')::date);
  perform compute_daily_global_stats((now() at time zone 'utc')::date - 1);
end;
$$;

-- Aggregation functions are cron/service-only, never client-callable.
revoke execute on function compute_daily_global_stats(date) from public, authenticated;
revoke execute on function refresh_global_stats() from public, authenticated;

-- Schedule via pg_cron. Guarded so `supabase db reset` also works on local
-- stacks where pg_cron isn't running; the hosted project has it.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule(
      'puff-refresh-global-stats',
      '10 3 * * *',
      $job$select refresh_global_stats()$job$
    );
  else
    raise notice 'pg_cron unavailable — schedule refresh_global_stats() manually';
  end if;
end;
$$;
