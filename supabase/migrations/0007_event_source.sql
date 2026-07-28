-- =============================================================================
-- Puff — event source (tapped vs. heard).
--
-- Acoustic detection (Listen mode, live duels) logs real events the user can
-- see and undo, but they are *not* health data: a chair squeak or a mouth
-- raspberry can produce one, and no classifier we can ship distinguishes them
-- reliably. So every event records how it arrived.
--
-- The hard line this column draws:
--   * 'tap'   — the user pressed the button. Feeds counts, streaks, badges and
--               the world aggregate. This is the gut-health log.
--   * 'heard' — the microphone decided. Feeds Listen mode and live duels only.
--               Never reported to user_daily_stats, so it can never reach
--               daily_global_stats: a population average polluted by furniture
--               is worthless, and world stats are the app's one claim to
--               health legitimacy.
--
-- Enforcement is client-side by construction (GlobalStatsService reports from
-- SourceFilter.tapped) — the server never sees a heard event in a stat report,
-- because stat reports carry only a (day, count) pair. This column exists so
-- the *cloud mirror* stays faithful to the device log through sync and restore.
--
-- Backfill: the default rewrites every pre-existing row to 'tap', which is
-- exactly what those events were — there was no other way to log one.
-- RLS is unchanged: heard events are still the user's own rows under the
-- policies from 0003, and 0006 already grants `events` to `authenticated`.
-- =============================================================================

alter table events
  add column if not exists source text not null default 'tap'
  check (source in ('tap', 'heard'));

-- Listen mode and live duels query "my heard events in this window"; the
-- existing (user_id, occurred_at desc) index doesn't discriminate by source.
create index if not exists events_user_source_occurred_idx
  on events (user_id, source, occurred_at desc);
