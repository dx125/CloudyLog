# CLAUDE.md

Guidance for Claude Code working in the CloudyLog repo.

## What it is

CloudyLog tracks daily "Clouding" actions against a configurable goal (default 35). Users can share results, view history on a color-coded calendar, and — as planned — compare with other users and friends via a backend.

## Repo layout

- `mobile/` — Flutter client (primary UI, fully functional against local storage)
- `backend/` — Cloudflare Workers API (scaffolded; not yet consumed by the mobile client)

Each subfolder is an independent project with its own tooling.

## mobile/ — Flutter app

**Stack:** Flutter ≥3.22 / Dart ^3.4, Provider, `shared_preferences`, `share_plus`, `table_calendar`, ARB localization (English + Spanish).

**Commands (run from `mobile/`):**
- `flutter pub get`
- `flutter gen-l10n` — regenerate `lib/l10n/generated/app_localizations.dart` after editing ARB files (auto-runs on `flutter run` because `generate: true`)
- `flutter run`
- `flutter test`

**Layered architecture under `lib/`:**

| Layer | Folders | Responsibility |
|---|---|---|
| Presentation | `presentation/screens`, `presentation/widgets`, `presentation/utils` | Widgets, navigation, per-screen logic |
| Service | `services/` | `CloudingService`, `ConfigService`, `LoginService`, `ShareService` — ChangeNotifier state |
| Data | `data/`, `data/models` | Repository interfaces + `SharedPrefs*` concrete impls |

`main.dart` builds a `MultiProvider`; `app.dart` gates `LoginScreen` vs `HomeScreen` and binds `MaterialApp.locale` to `ConfigService.locale`.

**Conventions:**
- Never hardcode user-visible strings. Add to [app_en.arb](mobile/lib/l10n/app_en.arb) and [app_es.arb](mobile/lib/l10n/app_es.arb), regenerate.
- Repositories are abstract interfaces; services depend on the interface, tests supply in-memory fakes.
- Services extend `ChangeNotifier` and call `notifyListeners()` after mutations.
- Clouding counts are stored per-day under SharedPreferences keys `clouding_count_YYYY-MM-DD`.

**Calendar coloring rules** ([goal_status.dart](mobile/lib/presentation/utils/goal_status.dart)):
- `count >= goal` → green (reached)
- `count >= 50% of goal` → orange (close)
- `0 < count < 50%` → red (low)
- No stored entry → no color

## backend/ — Cloudflare Workers API

**Stack:** TypeScript ESM, Hono router, Drizzle ORM, Neon serverless Postgres (HTTP driver), `jose` (JWT + Google ID-token verification), PBKDF2 via Web Crypto.

**Commands (run from `backend/`):**
- `npm install`
- `cp .env.example .dev.vars` and fill `DATABASE_URL`, `JWT_SECRET`, `GOOGLE_CLIENT_ID`
- `npm run db:generate` — drizzle-kit → `backend/drizzle/*.sql`
- `npm run db:migrate` — apply SQL to Neon
- `npm run dev` — wrangler dev locally
- `npm run typecheck`, `npm test`
- `npm run deploy` (after `wrangler secret put ...` for prod)

**Layered architecture under `src/`:**

| Layer | Folder | Notes |
|---|---|---|
| Domain | `domain/` | Pure types, zero deps |
| Application | `application/ports`, `application/use-cases` | Interfaces + one class per use case |
| Infrastructure | `infrastructure/db`, `infrastructure/auth`, `infrastructure/clock` | Drizzle repos, PBKDF2 hasher, JWT issuer, Google verifier, system clock |
| Presentation | `presentation/app.ts`, `presentation/routes`, `presentation/middleware` | Hono app, routes, Bearer-token middleware |
| Composition root | `composition.ts` | Wires interfaces → concrete impls |
| Entry point | `worker.ts` | Fetch + scheduled (cron) handlers |

**Data model** (see [schema.ts](backend/src/infrastructure/db/schema.ts)):
- `users` (id, email UNIQUE, display_name, password_hash, created_at)
- `auth_identities` (user_id, provider, provider_subject) — one user, many providers
- `clouding_entries` (user_id, day, count, updated_at) — PK `(user_id, day)`, incremented in place
- `friendships` (requester_id, addressee_id, status, created_at)
- `daily_aggregates` (day, total_users, p50, p75, p90, distribution JSONB, computed_at)

**API surface (JSON, Bearer auth except `/auth/*` and `/healthz`):**
- `POST /auth/signup`, `POST /auth/signin`, `POST /auth/google`
- `POST /cloudings/today/increment`
- `GET /stats/today` → `{count, percentile, totalUsers}`
- `POST /friends/requests`, `POST /friends/requests/:requesterId/respond`, `GET /friends/today`

**Conventions:**
- Use-cases accept dependencies via constructor. No singletons, no globals.
- Infra classes are named `<Technology><Role>` (e.g. `DrizzleUserRepository`, `JwtTokenIssuer`, `JoseGoogleIdTokenVerifier`).
- Edge-compatible only — no Node-only APIs. Stick to Fetch + Web Crypto so the worker runs on the free tier without `nodejs_compat`.
- The cron trigger recomputes `daily_aggregates` every 6 hours (see [wrangler.toml](backend/wrangler.toml)); `GetTodayStats` reads the cached snapshot rather than recomputing per request.

## Known gaps

- Mobile is not yet wired to the backend API. Swap-points are already in place:
  - Add an `ApiCloudingRepository` behind `CloudingRepository`
  - Replace the `LoginService` stub with a real impl that hits `/auth/*`
  - Persist the JWT in `AuthRepository` instead of the fake user
- Google Sign-In on mobile is a stub (no `google_sign_in` package yet).
- Friend-related UI on mobile doesn't exist yet; the server endpoints do.
