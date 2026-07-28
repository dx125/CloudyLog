# CLAUDE.md

Guidance for Claude Code working in the Puff repo.

## What it is

**Puff** — the gut health tracker that doesn't take itself seriously. One giant button counts your toots; underneath the joke it's a legitimate gut-health log. Product strategy, brand rules, tokens and roadmap live in `Documentation/`:

- [puff-handoff.md](Documentation/puff-handoff.md) — positioning, free/pro split, monetization, roadmap, architecture. **Read this before product decisions.**
- [puff-design-book.html](Documentation/puff-design-book.html) — brand, tokens, mascot construction, components, main-screen spec.
- [TODO.md](Documentation/TODO.md) — everything deliberately deferred (Phase 2/3 + infrastructure like RevenueCat, Sentry/PostHog, push). Check here before "adding" a missing feature; it may be parked on purpose.

Current build covers **Phase 0 (tap loop, local history, 7-day chart, streaks) and Phase 1 (world comparison — live for every tier, badges, share cards, anonymous accounts, Pro with cloud sync and full stats, basic Wrapped)**, plus a diagnostics log under Settings (You → Settings → Diagnostics) and once-daily anonymous stats reporting from all tiers.

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
- `flutter run --dart-define-from-file=.env` — cloud-connected run; copy `mobile/.env.example` to `mobile/.env` and fill in the Supabase URL + publishable key (`.env` is gitignored). Equivalent long form: `--dart-define=PUFF_SUPABASE_URL=... --dart-define=PUFF_SUPABASE_PUBLISHABLE_KEY=...`. Omit entirely to run 100% on-device.
- `flutter test`, `flutter analyze`

Note: `pubspec.yaml` pins `sqlparser: 0.44.5` in `dependency_overrides` — drift_dev 2.34 breaks against sqlparser 0.44.6. Drop the pin when drift_dev ships a fix.

**Android host (regenerated — reapply after `flutter create`):** the native `android/` scaffold is gitignored, so anything edited there is lost on recreation. Two edits are required for acoustic detection, on top of the branding steps below:
- `AndroidManifest.xml` — add `<uses-permission android:name="android.permission.RECORD_AUDIO" />`. **No foreground-service type**: Puff listens only while foregrounded, which keeps the Play Console FGS declaration + demo-video requirement off the table entirely.
- `app/build.gradle.kts` — `minSdk = maxOf(flutter.minSdkVersion, 26)`. LiteRT needs 26 (`record` needs 23). Raise, never lower.

**App icon & splash (branding):** the native `android/` scaffold is gitignored and recreated with `flutter create --platforms=android .`, so the icon/splash are *regeneratable sources*, not committed native files. Tracked source of truth: the Gust PNGs in `mobile/assets/branding/` (rendered from the mascot geometry by `tool/render_brand_assets.dart` via `flutter test tool/render_brand_assets.dart`) plus the `flutter_launcher_icons` and `flutter_native_splash` config blocks in `pubspec.yaml`. After (re)creating the android host, reapply branding: `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`, then set `android:label` to `Puff` in `AndroidManifest.xml`. The icon is the design book's App Store icon (bright mint Gust on ink; adaptive + Android-13 monochrome themed); the splash centers Gust on cloud (light) / ink-deep (dark). On Android 12+ the OS masks the launch image to a circle, so the `android_12` block uses **splash-colored** Gust icons (deep-teal on cloud / mint on ink-deep — the `splash_icon*` assets, not the mint launcher foreground) with `icon_background_color` set equal to the canvas: the disc blends into the screen and only Gust reads, matching the static splash instead of showing a launcher-style disc.

The splash is **two-stage** (Design Book §09). *Stage one* is that native launch image — just the Gust mark on the exact canvas color, all the OS can reliably show before Flutter boots (Android 12+ masks it to an icon, so text can't live here). *Stage two* is [`SplashScreen`](mobile/lib/presentation/screens/splash_screen.dart): an in-app widget (floating Gust + wordmark + tagline + three pulsing loading dots) shown by `SplashGate` while **local** init runs (Drift open/migrate, cache warm, entitlement). It's minimum-not-maximum: init under 300 ms skips stage two's visible frame and cuts straight home; slower boots keep it until ready, then Gust floats up and off the top while home cross-fades in (150 ms opacity fade under reduced motion). Wiring: `main()` no longer awaits the loads — it passes that future to `PuffApp(initialization:)` → `SplashGate`. Never gate the splash on the network.

**Architecture (offline-first — the one non-negotiable):** the Drift store is the source of truth; the server is a sync target and stats engine, never a dependency of the core loop. A tap must register in under 100 ms in airplane mode. Haptics/animation fire on the raw gesture handler (in `TapButton`), before any DB write.

| Layer | Folders | Contents |
|---|---|---|
| Domain | `lib/domain/` | `PuffEvent` (append-only event model, uuidv7, `EventSource`), streaks, badges, percentile, world range, entitlement, `acoustic.dart` (signature, `suggestedTag`, `OnsetDetector`) — pure Dart |
| Data | `lib/data/` | `EventStore` interface + Drift impl (`data/drift/`), `SettingsRepository` (prefs), gateway interfaces (`gateways.dart`) + Supabase impls (`data/supabase/`), acoustic impls (`data/acoustic/`), `DiagnosticsStore` (bounded JSONL file log with rotation) |
| Services | `lib/services/` | `TapService` (core loop + 10 s quick-tag window + `logHeard`), `StatsService` (derives everything from events), `EntitlementService`, `AuthService`, `SyncService` (debounced push, restore pull), `GlobalStatsService` (world-aggregate cache + once-daily stats report), `ListenService` (mic session + detection cascade), `DiagnosticsService` (in-app error log), `SettingsService`, `ShareService` |
| Presentation | `lib/presentation/` | Shell nav (Home/Stats/Duels/You) in `app.dart`; screens + widgets (`TapButton`, `PillButton`, `WeekChart`, paywall sheet, share cards) |
| Brand | `lib/theme/puff_theme.dart`, `lib/branding/gust.dart` | Design-book tokens (light+dark, `PuffColors` ThemeExtension), Gust mascot painter (one ellipse + three circles, always) |

**Acoustic detection (in progress — [design](Documentation/live-detection-design.md), [analysis](Documentation/live-detection-analysis.md)):** the mic can log toots it hears. The cascade is a cheap `OnsetDetector` energy gate → ring buffer → classifier (YAMNet trunk, Apache-2.0, + our trained head) on a background isolate → threshold + refractory. Capture runs with **AGC, noise suppression and echo cancellation all off** — they're speech-tuned, and a noise suppressor treats a toot as the noise. The training corpus must be captured with those same settings.

`YamnetClassifier` needs `assets/acoustic/head.bin`, which doesn't exist yet (it needs the spike + a labelled corpus). `HeuristicClassifier` is a DSP-only stand-in selected by `--dart-define=PUFF_ACOUSTIC_HEURISTIC=true`; it must never ship as the detector.

Shipped: **tag assist** (opt-in at You → Settings, marks a suggested quick-tag chip on Home, writes nothing) and **Listen mode** ([`ListenScreen`](mobile/lib/presentation/screens/listen_screen.dart), reached from the mic pill on Home — a session the user enters, logs heard events, every one dismissible, 5-minute free budget then the paywall).

**Duels** ([`DuelService`](mobile/lib/services/duel_service.dart), migrations `0008`/`0009`, `duels` edge function). Two kinds share one table:
- **async** — tap-scored, a week long. The real competition, and the retention mechanic.
- **live** — heard-scored, 3-minute rounds, both phones in Listen mode ([`DuelRoundScreen`](mobile/lib/presentation/screens/duel_round_screen.dart)). **Honour-system party mode**: a mouth raspberry beats any classifier we can ship, so the copy says so instead of implying verification. Anti-cheat is social.

Rules that hold the design together: creating a duel is Pro (enforced in RLS), **joining is always free** — the invited person is the acquisition. Scores are *submitted* and server-validated (plausibility clamps + monotonic), because the server has no raw events for free users. Live rounds broadcast one coalesced count every 2 s, never per detection: the Realtime budget is 500 msg/s project-wide ≈ 250 concurrent rounds. The authoritative score always goes through the edge function, never a broadcast a peer could forge.

**Duel names are curated-wordlist indices, never free text** ([`duel.dart`](mobile/lib/domain/duel.dart)). That deletes TODO.md's profanity-filter blocker rather than mitigating it — there is no column a slur can go in. The lists are **append-only**: reordering renames every existing duel, since the server stored a position.

Testing note: `ListenService.stop()` finishes on a real event-loop turn (`StreamSubscription.cancel()`), so widget tests need `tester.runAsync(...)` to observe the mic being released — draining microtasks never will. The capture fake yields with `await null` rather than `Future.delayed`, because a zero-duration delay is a *timer* and deadlocks under `testWidgets`.

**Key invariants:**
- Events are append-only; **never store or update counters** — counts, streaks, badges, charts, Wrapped all derive from events. Only `tags` may change (10 s window), which clears `syncedAt` so the edit re-pushes.
- **Heard ≠ tapped.** `PuffEvent.source` splits them, and `SourceFilter` defaults to `tapped` on every counting query so a forgetful caller gets the safe answer. Heard events (Listen mode, live duels) never reach counts, streaks, badges, charts, Wrapped, or `report-stats` — a world average polluted by chair squeaks is worthless. Acoustic detection never writes on its own either: tag assist only *marks* a chip, and the user still taps it.
- Client-generated UUIDv7 ids make sync idempotent (server upsert, last-write-wins).
- Cloud sync is Pro-only and additionally enforced server-side by RLS. The once-daily anonymous stats report (`report-stats`; one `(day, count)` row per day) is every tier — it's participation in world stats, not sync, and the privacy note in the app discloses it.
- Silent failures aren't silent: gateways, global handlers and catch-and-carry-on sites report through `DiagnosticsService.record` (surfaced at You → Settings → Diagnostics with copy/share export). New swallow sites must record too.
- No drop shadows; depth = pillow offsets and surface steps. Coral appears at most once per screen (Pro markers, streaks, celebrations).
- Never hardcode user-visible strings; add to [app_en.arb](mobile/lib/l10n/app_en.arb) and regenerate.
- Repositories/gateways are interfaces; services take them via constructor (+ injectable `clock` for time-dependent logic); tests use fakes from [test/fakes.dart](mobile/test/fakes.dart).
- Reduced motion: bobbing/puff animations off, color pulse stays, haptic always fires.

## supabase/ — backend

First-time setup (local stack + hosted project) is a step-by-step runbook at [supabase/README.md](supabase/README.md).

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
- `0005_stat_reports.sql` — `user_daily_stats`: one `(day, toot_count)` row per user per local day, own-row RLS with **no Pro gate** (world stats need everyone). Re-points `compute_daily_global_stats()` at these reports instead of raw events, so aggregates cover free users and never scan `events`.

**Edge functions (`functions/`)** — the app's entire backend API; the client **never** queries tables or RPCs directly (the only non-function APIs are Supabase Auth and, for live duels, Realtime — see `0009`). Each function forwards the caller's JWT (`_shared/edge.ts` → `userClient`), so RLS and definer functions keep applying — functions are the API surface, not a privilege bypass; no service_role anywhere.
- `sync-events` — POST idempotent event upsert (Pro-gated by RLS → 403), GET full pull for restore.
- `entitlements` — GET entitlement; POST `{action: purchase|cancel}` → mock billing RPCs.
- `global-stats` — GET latest anonymous aggregate row.
- `report-stats` — POST once-daily upsert of the caller's per-day toot counts (any tier; feeds the world aggregates).
- `account` — DELETE → `delete_my_account()`.
- `duels` — GET list/preview; POST `{action: create|join|score|leave}`. Enforces the two things RLS can't express: plausibility clamps and monotonic scores.

**Conventions:** auth flow is anonymous-first (`enable_anonymous_sign_ins = true`), upgraded in place via `auth.updateUser`. Every new table gets RLS in the same migration that creates it — no exceptions. New backend capabilities get an edge function, not a client-side table/RPC call; inside functions use the caller's JWT, never assume service_role.

## Testing

- Mobile: `flutter test` — domain rules (streaks/badges/percentile) and services against in-memory fakes; no DB or network in tests.
- Backend: no test harness yet; migrations are verified by `supabase db reset` on the local stack.

## Payments (current state)

Mock only: `PurchaseGateway` (client seam) → `entitlements` edge function → `activate_mock_pro` RPC → `entitlements` row (30 days/activation, cancel keeps Pro until expiry). Real billing = RevenueCat SDK + webhook Edge Function; see TODO.md. Prices from the handoff: $2.49/mo, $17.99/yr, $29.99 lifetime.
