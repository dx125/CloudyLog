-- =============================================================================
-- Puff — explicit API-role table grants.
--
-- RLS decides *which rows* a caller sees; a base table GRANT decides whether
-- the role may touch the table at all — and it's checked *before* RLS. Supabase
-- normally hands anon/authenticated these privileges via default privileges,
-- but that's implicit project state: when it's absent (or a project predates
-- it), every edge-function query fails with
--   "permission denied for table <name>"   (Postgres 42501 → our 500s)
-- before RLS is ever consulted. Granting here makes the backend self-contained
-- and portable across projects; the RLS policies from 0001–0005 still constrain
-- every row, and writes to entitlements stay definer-RPC-only.
--
-- The app runs as an anonymous *session* (Postgres role `authenticated`), which
-- is exactly what every RLS policy targets, so privileges go to `authenticated`.
-- =============================================================================

grant usage on schema public to authenticated;

-- profiles (0001): read/update own; inserts are trigger/definer only.
grant select, update on profiles to authenticated;

-- entitlements (0002): read own only; all writes go through definer RPCs.
grant select on entitlements to authenticated;

-- events (0003): full own-row CRUD; insert/update additionally Pro-gated by RLS.
grant select, insert, update, delete on events to authenticated;

-- daily_global_stats (0004): anonymous aggregate, read-only for clients.
grant select on daily_global_stats to authenticated;

-- user_daily_stats (0005): own-row CRUD; every tier reports here.
grant select, insert, update, delete on user_daily_stats to authenticated;
