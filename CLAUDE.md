# CLAUDE.md

Guidance for Claude Code working in the CloudyLog repo.

## What it is

CloudyLog tracks daily "Clouding" actions against a configurable goal (default 35). Users can share results and view history on a color-coded calendar.

**Tiers:**
- **Free** — no account, no network. All data and history stay on the device.
- **Pro** (subscription) — requires an account; adds cloud storage of history, country/worldwide percentile comparisons, and friends (requests + today's leaderboard). Billing is currently a **mock provider** (server grants 30 days per activation); store billing (Google Play / App Store) plugs in behind the same `PurchaseValidator` port later.

## Repo layout

- `mobile/` — Flutter client (works fully offline on the free tier; talks to the backend for Pro features)
- `backend/` — Cloudflare Workers API

Each subfolder is an independent project with its own tooling.

## mobile/ — Flutter app

**Stack:** Flutter ≥3.22 / Dart ^3.4, Provider, `http`, `shared_preferences`, `share_plus`, `table_calendar`, ARB localization (English + Spanish).

**Commands (run from `mobile/`):**
- `flutter pub get`
- `flutter gen-l10n` — regenerate `lib/l10n/generated/app_localizations.dart` after editing ARB files (auto-runs on `flutter run` because `generate: true`)
- `flutter run --dart-define=CLOUDYLOG_API_URL=http://10.0.2.2:8787` (defaults to `http://localhost:8787`; Android emulators need `10.0.2.2`)
- `flutter test`

**Layered architecture under `lib/`:**

| Layer | Folders | Responsibility |
|---|---|---|
| Presentation | `presentation/screens`, `presentation/widgets`, `presentation/utils` | Widgets, navigation, per-screen logic |
| Service | `services/` | `CloudingService`, `ConfigService`, `LoginService`, `SubscriptionService`, `SyncService`, `ShareService` — ChangeNotifier state |
| Data | `data/`, `data/models`, `data/api` | Repository + gateway interfaces; `SharedPrefs*` impls; `ApiClient` + `Api*Gateway` impls |

`main.dart` builds the object graph (repos → `ApiClient` → gateways → services) and a `MultiProvider`; `app.dart` opens straight into `HomeScreen` (free tier needs no login) and binds `MaterialApp.locale` to `ConfigService.locale`.

**Tier flow on mobile:**
- All Clouding data is stored on-device under the fixed profile `kLocalProfileId` (`'local'`), signed in or not. The device is the source of truth.
- `ProScreen` (Account & Pro hub) hosts sign-in/sign-up (`LoginScreen`), the mock-purchase paywall, and subscription management (cancel keeps Pro until expiry).
- On upgrade (or signing into an already-Pro account), `SyncService.syncAll` uploads the full local history; the server merges by **max per day** and the merged view is written back locally.
- While Pro and signed in, a listener in `main.dart` pushes today's absolute count (`PUT /cloudings/today`) after each change — resets propagate; offline pushes are dropped and reconciled by the next `syncAll`.
- `SubscriptionService.isPro` gates the Pro UI (stats/friends icons on Home); the cached entitlement self-downgrades past `expiresAt` even offline.
- Country defaults from the device locale at sign-up and is editable in Settings (PATCH `/me`).

**Conventions:**
- Never hardcode user-visible strings. Add to [app_en.arb](mobile/lib/l10n/app_en.arb) and [app_es.arb](mobile/lib/l10n/app_es.arb), regenerate.
- Repositories/gateways are abstract interfaces; services depend on the interface, tests supply in-memory fakes (see [test/fakes.dart](mobile/test/fakes.dart)).
- Services extend `ChangeNotifier` and call `notifyListeners()` after mutations.
- Clouding counts are stored per-day under SharedPreferences keys `clouding_count_<profileId>_YYYY-MM-DD`.

**Calendar coloring rules** ([goal_status.dart](mobile/lib/domain/goal_status.dart)):
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
| Domain | `domain/` | Pure types + rules (`subscription.ts` holds the entitlement rule), zero deps |
| Application | `application/ports`, `application/use-cases` | Interfaces + one class per use case |
| Infrastructure | `infrastructure/db`, `infrastructure/auth`, `infrastructure/billing`, `infrastructure/clock` | Drizzle repos, PBKDF2 hasher, JWT issuer, Google verifier, `MockPurchaseValidator`, system clock |
| Presentation | `presentation/app.ts`, `presentation/routes`, `presentation/middleware` | Hono app, routes, `requireAuth` + `requirePro` middleware |
| Composition root | `composition.ts` | Wires interfaces → concrete impls (swap billing here) |
| Entry point | `worker.ts` | Fetch + scheduled (cron) handlers |

**Data model** (see [schema.ts](backend/src/infrastructure/db/schema.ts)):
- `users` (id, email UNIQUE, display_name, password_hash, country, created_at) — country is ISO 3166-1 alpha-2 or null
- `auth_identities` (user_id, provider, provider_subject) — one user, many providers
- `subscriptions` (user_id PK, status, provider, started_at, expires_at, updated_at) — status `active|canceled`; entitlement = `expires_at > now` regardless of status
- `clouding_entries` (user_id, day, count, updated_at) — PK `(user_id, day)`
- `friendships` (requester_id, addressee_id, status, created_at)
- `daily_aggregates` (day, country, total_users, p50, p75, p90, distribution JSONB, computed_at) — PK `(day, country)`; country `'*'` is the worldwide row

**API surface (JSON, Bearer auth except `/auth/*` and `/healthz`; ★ = also requires an active Pro subscription, else 403 `pro_required`):**
- `POST /auth/signup` (accepts optional `country`), `POST /auth/signin`, `POST /auth/google`
- `GET /me`, `PATCH /me` — profile + subscription snapshot; update displayName/country
- `GET /subscription`, `POST /subscription/activate` (`{provider:'mock', receipt}`), `POST /subscription/cancel`
- ★ `POST /cloudings/today/increment`, `PUT /cloudings/today` (absolute count), `GET /cloudings`, `POST /cloudings/sync` (bulk upload, max-merge per day, returns merged history)
- ★ `GET /stats/today?scope=worldwide|country` → `{day, scope, country, count, percentile, totalUsers}` (400 `country_not_set` if scope=country and no country)
- ★ `POST /friends/requests`, `GET /friends/requests` (pending), `POST /friends/requests/:requesterId/respond`, `GET /friends/today`

**Conventions:**
- Use-cases accept dependencies via constructor. No singletons, no globals.
- Infra classes are named `<Technology><Role>` (e.g. `DrizzleUserRepository`, `JwtTokenIssuer`, `MockPurchaseValidator`).
- Edge-compatible only — no Node-only APIs. Stick to Fetch + Web Crypto so the worker runs on the free tier without `nodejs_compat`.
- The cron trigger recomputes `daily_aggregates` (worldwide + per country) every 6 hours (see [wrangler.toml](backend/wrangler.toml)); `GetTodayStats` reads the cached snapshot rather than recomputing per request.
- Test fakes for ports live in [fakes.test-helpers.ts](backend/src/application/use-cases/fakes.test-helpers.ts).

## Known gaps

- **Billing is mocked**: `MockPurchaseValidator` accepts any receipt for provider `'mock'` and grants 30 days. Real store billing = implement `PurchaseValidator` for Play/App Store receipts, swap in `composition.ts`, and use `in_app_purchase` on mobile behind `SubscriptionGateway.activateMock`'s replacement.
- Google Sign-In on mobile is unavailable (no `google_sign_in` package); the backend `/auth/google` endpoint is ready and `LoginService.signInWithGoogle` returns `googleUnavailable` until wired.
- `PUT /cloudings/today` uses the server's UTC day; a device near midnight in a distant timezone can write to the adjacent UTC day. Acceptable for now; fix by sending the client's day.
- No token refresh: JWTs last 30 days; an expired token surfaces as failed Pro calls until the user signs in again.
