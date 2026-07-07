# CLAUDE.md

Guidance for Claude Code working in the Puff repo.

## What it is

**Puff** — the gut health tracker that doesn't take itself seriously. One giant button counts your toots; underneath the joke it's a legitimate gut-health log. Product strategy, brand rules, tokens and roadmap live in `Documentation/`:

- [puff-handoff.md](Documentation/puff-handoff.md) — positioning, free/pro split, monetization, roadmap, architecture. **Read this before product decisions.**
- [puff-design-book.html](Documentation/puff-design-book.html) — brand, tokens, mascot construction, components, main-screen spec.
- [TODO.md](Documentation/TODO.md) — everything deliberately deferred (Phase 2/3 + infrastructure like RevenueCat, Sentry/PostHog, push). Check here before "adding" a missing feature; it may be parked on purpose.

Current build covers **Phase 0 (tap loop, local history, 7-day chart, streaks) and Phase 1 (world comparison, badges, share cards, anonymous accounts, Pro with cloud sync and full stats, basic Wrapped)**.

Voice rules (enforced in review): cheeky never crude, one joke per screen, sentence case, contractions, health language is ranges/patterns only ("most people land between 10 and 20"), "toot" in all user-facing text, no brown anywhere, ever.

## Repo layout

- `mobile/` — Flutter app (package `puff`). Offline-first; fully functional with zero cloud config.
- `supabase/` — Supabase project: `config.toml`, SQL migrations, and edge functions (the app's only backend API). RLS is the security model; the functions are the API surface on top of it.

## mobile/ — Flutter app

**Stack:** Flutter ≥3.22 / Dart ^3.4, Provider, Drift (SQLite), `supabase_flutter`, `google_fonts` (Baloo 2 + Nunito), `share_plus`, `shared_preferences`, `uuid` (v7), ARB l10n (English only — more locales are Phase 3).

**Commands (run from `mobile/`):**
- `flutter pub get`
- `dart run build_runner build --delete-conflicting-outputs` — regenerate Drift code after editing `lib/data/drift/puff_database.dart`
- `flutter gen-l10n` — after editing `lib/l10n/app_en.arb`
- `flutter run --dart-define-from-file=.env` — cloud-connected run; copy `mobile/.env.example` to `mobile/.env` and fill in the Supabase URL + anon key (`.env` is gitignored). Equivalent long form: `--dart-define=PUFF_SUPABASE_URL=... --dart-define=PUFF_SUPABASE_ANON_KEY=...`. Omit entirely to run 100% on-device.
- `flutter test`, `flutter analyze`

Note: `pubspec.yaml` pins `sqlparser: 0.44.5` in `dependency_overrides` — drift_dev 2.34 breaks against sqlparser 0.44.6. Drop the pin when drift_dev ships a fix.

**Architecture (offline-first — the one non-negotiable):** the Drift store is the source of truth; the server is a sync target and stats engine, never a dependency of the core loop. A tap must register in under 100 ms in airplane mode. Haptics/animation fire on the raw gesture handler (in `TapButton`), before any DB write.

| Layer | Folders | Contents |
|---|---|---|
| Domain | `lib/domain/` | `PuffEvent` (append-only event model, uuidv7), streaks, badges, percentile, world range, entitlement — pure Dart |
| Data | `lib/data/` | `EventStore` interface + Drift impl (`data/drift/`), `SettingsRepository` (prefs), gateway interfaces (`gateways.dart`) + Supabase impls (`data/supabase/`) |
| Services | `lib/services/` | `TapService` (core loop + 10 s quick-tag window), `StatsService` (derives everything from events), `EntitlementService`, `AuthService`, `SyncService` (debounced push, restore pull), `SettingsService`, `ShareService` |
| Presentation | `lib/presentation/` | Shell nav (Home/Stats/Duels/You) in `app.dart`; screens + widgets (`TapButton`, `PillButton`, `WeekChart`, paywall sheet, share cards) |
| Brand | `lib/theme/puff_theme.dart`, `lib/branding/gust.dart` | Design-book tokens (light+dark, `PuffColors` ThemeExtension), Gust mascot painter (one ellipse + three circles, always) |

**Key invariants:**
- Events are append-only; **never store or update counters** — counts, streaks, badges, charts, Wrapped all derive from events. Only `tags` may change (10 s window), which clears `syncedAt` so the edit re-pushes.
- Client-generated UUIDv7 ids make sync idempotent (server upsert, last-write-wins).
- Cloud sync is Pro-only and additionally enforced server-side by RLS.
- No drop shadows; depth = pillow offsets and surface steps. Coral appears at most once per screen (Pro markers, streaks, celebrations).
- Never hardcode user-visible strings; add to [app_en.arb](mobile/lib/l10n/app_en.arb) and regenerate.
- Repositories/gateways are interfaces; services take them via constructor (+ injectable `clock` for time-dependent logic); tests use fakes from [test/fakes.dart](mobile/test/fakes.dart).
- Reduced motion: bobbing/puff animations off, color pulse stays, haptic always fires.

## supabase/ — backend

**Commands (run from `supabase/`'s parent or with `--workdir`):**
- `supabase start` — local stack (Docker); prints the anon key for `--dart-define` and serves edge functions at `/functions/v1/<name>`
- `supabase db reset` — replay migrations locally
- `supabase functions serve` — hot-reload edge functions during development
- `supabase link` + `supabase db push` + `supabase functions deploy` — apply migrations and functions to the hosted project

**Migrations:**
- `0001_profiles.sql` — profiles auto-created per auth user (anonymous included) via trigger; RLS own-row.
- `0002_entitlements.sql` — entitlement mirror; readable own-row, writable **only** through security-definer RPCs `activate_mock_pro()` / `cancel_mock_pro()` (dev billing; RevenueCat webhook replaces them later) and `delete_my_account()` (one-tap total deletion). `has_active_pro()` is the single entitlement predicate.
- `0003_events.sql` — cloud mirror of the device event log; RLS: select/delete own always, insert/update own **and** `has_active_pro()`.
- `0004_global_stats.sql` — anonymous `daily_global_stats` (histogram + percentiles), computed by `refresh_global_stats()` via pg_cron (03:10 UTC daily, hourly later); clients read aggregates only, never raw population data.

**Edge functions (`functions/`)** — the app's entire backend API; the client **never** queries tables or RPCs directly (the only non-function API is Supabase Auth itself). Each function forwards the caller's JWT (`_shared/edge.ts` → `userClient`), so RLS and definer functions keep applying — functions are the API surface, not a privilege bypass; no service_role anywhere.
- `sync-events` — POST idempotent event upsert (Pro-gated by RLS → 403), GET full pull for restore.
- `entitlements` — GET entitlement; POST `{action: purchase|cancel}` → mock billing RPCs.
- `global-stats` — GET latest anonymous aggregate row.
- `account` — DELETE → `delete_my_account()`.

**Conventions:** auth flow is anonymous-first (`enable_anonymous_sign_ins = true`), upgraded in place via `auth.updateUser`. Every new table gets RLS in the same migration that creates it — no exceptions. New backend capabilities get an edge function, not a client-side table/RPC call; inside functions use the caller's JWT, never assume service_role.

## Testing

- Mobile: `flutter test` — domain rules (streaks/badges/percentile) and services against in-memory fakes; no DB or network in tests.
- Backend: no test harness yet; migrations are verified by `supabase db reset` on the local stack.

## Payments (current state)

Mock only: `PurchaseGateway` (client seam) → `entitlements` edge function → `activate_mock_pro` RPC → `entitlements` row (30 days/activation, cancel keeps Pro until expiry). Real billing = RevenueCat SDK + webhook Edge Function; see TODO.md. Prices from the handoff: $2.49/mo, $17.99/yr, $29.99 lifetime.
