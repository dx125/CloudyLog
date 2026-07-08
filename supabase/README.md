# Puff backend — first launch

The backend is a Supabase project: Postgres with Row-Level Security as the
security model, and Edge Functions as the **only** API the app calls (it never
hits tables or RPCs directly — see [CLAUDE.md](../CLAUDE.md)). This is the
runbook for standing it up the first time, locally and hosted.

All `supabase` commands run from the **repo root** (`CloudyLog/`, the folder
that contains this `supabase/` directory), or from anywhere with
`--workdir <path-to-CloudyLog>`.

What gets applied either way:

| Migration | Adds |
|---|---|
| `0001_profiles.sql` | `profiles`, auto-created per auth user by a trigger |
| `0002_entitlements.sql` | `entitlements` + `has_active_pro()` + mock-billing / delete RPCs |
| `0003_events.sql` | `events` cloud mirror (insert/update Pro-gated by RLS) |
| `0004_global_stats.sql` | anonymous `daily_global_stats` + `refresh_global_stats()` + pg_cron job |
| `0005_stat_reports.sql` | `user_daily_stats` (every tier reports one `(day, count)` row/day); repoints the aggregate at it |

Functions: `sync-events`, `entitlements`, `global-stats`, `report-stats`,
`account`. All have `verify_jwt = true`, so every request needs an
`Authorization` header — the app always sends one (auth is anonymous-first).
None use `service_role`; they run with the caller's JWT.

---

## Prerequisites

- **Supabase CLI** — `supabase --version` (install: <https://supabase.com/docs/guides/cli>).
- **Docker Desktop** — local stack only; must be *running* before `supabase start`.
- Deno is bundled with the CLI; no separate install for `functions serve` / `deploy`.

---

## A. Local stack (development)

1. **Start Docker Desktop** and wait until it reports running.

2. **Boot the stack** (from the repo root):
   ```bash
   supabase start
   ```
   First run pulls images (slow), applies every migration, then prints the
   **API URL**, **anon key**, **service_role key**, and **Studio URL**. Keep
   the anon key — the app needs it. (Re-print later with `supabase status`.)

3. **Serve the edge functions** (hot-reload; separate terminal):
   ```bash
   supabase functions serve
   ```
   They're served at `http://localhost:54321/functions/v1/<name>`. The
   platform auto-injects `SUPABASE_URL` / `SUPABASE_ANON_KEY` — no secrets to
   set (the functions never use `service_role`).

4. **Replay migrations** after editing any SQL:
   ```bash
   supabase db reset
   ```
   This re-runs `0001`→`0005` on a clean database.

5. **Wire the app** — copy `mobile/.env.example` to `mobile/.env` and fill in:
   ```
   PUFF_SUPABASE_URL=http://localhost:54321
   PUFF_SUPABASE_ANON_KEY=<anon key from step 2>
   ```
   From the **Android emulator** use `http://10.0.2.2:54321` (localhost there
   is the emulator itself). Then:
   ```bash
   cd mobile && flutter run --dart-define-from-file=.env
   ```

6. **Global stats need a manual nudge locally.** `pg_cron` isn't in the local
   stack, so `daily_global_stats` stays empty until you compute it. Once at
   least one `user_daily_stats` row exists (open the app and tap a few times, or
   insert one in Studio), run in **Studio → SQL Editor**:
   ```sql
   select refresh_global_stats();
   ```
   The Stats screen's world comparison populates on the next refresh.

---

## B. Hosted project (staging / production)

1. **Create the project** in the Supabase dashboard. Note the **project ref**
   (`<ref>.supabase.co`) and the database password.

2. **Enable `pg_cron`** — Dashboard → Database → Extensions → enable `pg_cron`.
   Do this **before** the DB push so the daily global-stats job schedules
   itself. (If you forget, see step 7 to schedule it after the fact.)

3. **Configure Auth** — Dashboard → Authentication → Providers/Settings:
   - **Enable anonymous sign-ins** — non-negotiable; the whole app is
     anonymous-first and nothing authenticates without it.
   - **Turn ON email confirmations** for real deployments (`config.toml` ships
     them *off* for local convenience).

4. **Log in and link:**
   ```bash
   supabase login
   supabase link --project-ref <ref>
   ```

5. **Apply migrations:**
   ```bash
   supabase db push
   ```

6. **Deploy the functions:**
   ```bash
   supabase functions deploy
   ```
   (Or one at a time: `supabase functions deploy sync-events`, etc.) No
   `supabase secrets set` is needed — the functions only use the
   auto-injected URL/anon key plus the caller's JWT.

7. **Verify the cron job** — Studio → SQL Editor:
   ```sql
   select jobname, schedule from cron.job;   -- expect puff-refresh-global-stats @ '10 3 * * *'
   ```
   If it's missing (pg_cron was enabled after the push), enable it then run:
   ```sql
   select cron.schedule('puff-refresh-global-stats', '10 3 * * *',
     $$select refresh_global_stats()$$);
   ```

8. **Bootstrap the aggregate** — `daily_global_stats` is empty until the cron
   fires (03:10 UTC) or you trigger it once data exists:
   ```sql
   select refresh_global_stats();
   ```

9. **Wire the release build** — `mobile/.env` with the hosted values:
   ```
   PUFF_SUPABASE_URL=https://<ref>.supabase.co
   PUFF_SUPABASE_ANON_KEY=<Dashboard → Project Settings → API → anon/public key>
   ```
   Build with `flutter build <target> --dart-define-from-file=.env`.

---

## Smoke test (either path)

Point the app at the backend and:

1. **Tap a few times.** In Studio: a `profiles` row exists for the anonymous
   user.
2. **Reopen the app the next local day** (or trigger the startup warm-up) — a
   `user_daily_stats` row appears (this happens on **every** tier).
3. **Run `refresh_global_stats()`** with ≥1 report present → the Stats screen's
   "Today vs the world" card shows a percentile and participant count.
4. **Buy mock Pro** in the app → an `entitlements` row appears; keep tapping →
   `events` rows sync in (insert is Pro-gated by RLS, so this only works once
   Pro is active).
5. **Delete account** in the app → the auth user and everything cascading from
   it are gone.

---

## Gotchas

- **Anonymous sign-ins must be enabled** (hosted: dashboard; local: already on
  in `config.toml`). Without it, nothing authenticates and the cloud silently
  no-ops — check **You → Settings → Diagnostics** in the app for the recorded
  auth error.
- **No `service_role` anywhere** — not in `mobile/.env`, not in the client, not
  in a function. RLS + the caller's JWT is the entire model.
- **`pg_cron` is hosted-only.** Locally, compute aggregates by hand with
  `select refresh_global_stats();`.
- **Email confirmations**: off locally, on for hosted.
- **Free-tier stats reporting is on by default** — every tier sends one
  anonymous `(day, count)` row per day via `report-stats`. The app's privacy
  note discloses it; a client-side opt-out is parked in
  [Documentation/TODO.md](../Documentation/TODO.md).
