# Puff — Product & Strategy Handoff

**Version 1.0 · July 2026 · Companion to the Puff Design Book v1.0**

Puff is a mobile app that counts how often you fart. One giant button, one satisfying tap, and over time an oddly fascinating — and genuinely health-relevant — picture of your gut. This document is the working brief for anyone joining the project: what Puff is, who it's for, how it makes money, what ships free versus Pro, and how it should be built on the current Flutter + Supabase pilot and beyond.

---

## 1. Positioning

**One-liner:** the gut health tracker that doesn't take itself seriously.

Puff lives on a deliberate tension. On the surface it's a joke app — the kind people install to show friends, screenshot for the group chat, and challenge their partner with. Underneath, it's a legitimate gut-health log grounded in real research: healthy adults pass gas roughly 10–20 times a day, and changes in frequency track diet, microbiome, and GI conditions. Gastroenterologists literally ask patients to keep this diary; today those patients use notes apps.

The strategy is: **the joke acquires users, the data retains them.** Every product decision must survive both readings — it should make a teenager laugh and make an IBS patient feel respected. If a feature only works for one of those two people, it's probably wrong.

**Audiences, in order of importance:**

1. **The amused majority** — installs for fun, drives virality and reviews. Needs the tap loop, streaks, share cards, and duels. Low willingness to pay individually, enormous in volume.
2. **The gut-curious** — quantified-self people and anyone who's ever wondered "is this normal?" Converts on stats depth and food correlations.
3. **The GI community (IBS, SIBO, FODMAP dieters)** — small, highly motivated, medically advised to track exactly this. Converts on trigger-food analysis and the doctor report. This group is the long-term moat: no competitor will out-meme us *and* out-serve them.

**What Puff is not:** a medical device, a diagnosis tool, or a poop app. Health language is always ranges and patterns ("most people land between 10 and 20"), never conclusions. Brown is banned from the product forever.

---

## 2. Brand at a glance

Full spec lives in the Design Book; the essentials:

- **Name:** Puff. **Mascot:** Gust, a small cloud of air with a face — app icon, empty states, notification voice, future sticker pack.
- **World:** air, wind, breeze. Mint, teal, cream, ink, with one rationed coral accent (Pro, streaks, celebrations).
- **Type:** Baloo 2 for the brand's voice and all stat numerals, Nunito for reading.
- **Feel:** everything is round, nothing has a shadow, the tap button sits on a solid "pillow" and sinks when pressed. The tap interaction (haptic + Gust puffing up + counter roll, ~450 ms) *is* the product; it gets tuned forever.
- **Voice:** cheeky, never crude; one joke per screen; sentence case; contractions. We joke about the act, never at the person.

---

## 3. Free vs Pro

The free tier must be genuinely fun and complete — it is the marketing. Pro sells depth, memory, and social play, not the removal of annoyances. There are no ads in either tier.

| Capability | Free | Pro |
|---|---|---|
| Tap logging with haptics & animation | Yes | Yes |
| Quick tags (Silent / Squeaky / Thunder / SBD) | 4 tags | Full set + custom tags |
| History | Last 7 days, on-device | Unlimited, cloud-synced |
| World average comparison | Today only | Percentiles, cohorts, trends |
| Streaks & basic badges | Yes | Full badge collection |
| Weekly chart | Yes | Heatmaps, time-of-day, weekday patterns |
| **Trigger food detective** (meal tags → correlation) | — | Yes |
| **Doctor report** (clean PDF export) | — | Yes |
| Duels & leagues (head-to-head weeks, household leaderboard) | Join one duel | Unlimited, create leagues |
| Monthly/yearly **Wrapped** share cards | Basic year-end card | Full Wrapped, monthly editions |
| Watch app / home-screen widget one-tap logging | — | Yes |
| Health app integration (sleep, cycle, exercise overlays) | — | Yes |
| Multi-device sync & backup | — | Yes |
| Cosmetics (sound packs, themes, Gust seasonal skins) | 1 default pop sound | Included set + IAP packs |

Two features carry the subscription: the **trigger food detective** (log meals with quick tags; Puff correlates food to gas 4–12 hours later — real FODMAP-elimination territory, the reason someone pays for months) and the **doctor report** (unsexy, defensibly useful, earns press beyond the joke cycle).

---

## 4. Monetization

**Model: freemium + cheap subscription, priced as an impulse buy, plus cosmetic IAPs.**

- **Puff Pro:** $2.49/month or $17.99/year (position the annual as "under $1.50 a month"). At this price the paywall barely needs justification; conversion friction is the enemy, not price sensitivity.
- **Lifetime unlock:** $29.99. Joke-adjacent apps convert unusually well on lifetime because people gift them; it also de-risks churn among the amused majority.
- **Cosmetic IAPs outside the subscription:** sound packs ($0.99–1.99), themes, Gust outfits. Pure margin, and *giftable* — gifting the "brass ensemble" pack to a friend is itself a growth loop.
- **No ads.** Banners would kill the clean, screenshot-worthy feel that drives organic acquisition. If free-tier monetization is ever needed, the ceiling is a single rewarded ad ("watch to unlock today's detailed breakdown") — and even that should wait for data.

**Paywall placement:** never block the tap. Paywalls appear at moments of earned curiosity — tapping a locked chart, hitting day 8 of history, being invited to a second duel, or the year-end Wrapped teaser. The upgrade screen leads with the food detective, not the feature list.

**Honest unit economics note:** this is a volume business. Expect low single-digit percent conversion from the amused majority and materially higher (10%+) from GI-community users acquired through FODMAP/IBS content — which is why the "serious" features deserve real investment despite the silly wrapper.

---

## 5. Growth strategy

Puff lives or dies on shareability and App Store search, in that order.

1. **Share cards from day one.** Every milestone (streaks, personal records, badges, duel wins) generates a beautiful, mascot-branded card sized for stories and chats. Wrapped — monthly and yearly — is the flagship viral event; it ships in v1, not later. It is the growth model, not garnish.
2. **Duels as invitations.** A duel requires a second person; every duel is an install prompt with built-in social proof. Household/couple mode writes its own marketing.
3. **ASO:** "fart counter" and adjacent queries have real volume and near-zero quality competition. Title: "Puff — Fart Counter & Gut Tracker." Screenshots lead with the mascot and the big button, not charts.
4. **Two-track content:** meme-able clips of the tap/Gust for TikTok/Reels, and sincere "I tracked my farts for 30 days on a low-FODMAP diet" content for the GI audience. The press angle is the research hook (smart-underwear studies, fart-count-as-health-signal).
5. **Seasonal events:** bean-holiday challenges, seasonal Gust skins — cheap, recurring re-engagement.

---

## 6. Roadmap

- **Phase 0 — Pilot hardening (now):** perfect the tap loop (haptics, animation, latency), local history, 7-day chart, streaks. Ship nothing else until the tap feels great.
- **Phase 1 — Launch:** world-average comparison, badges, share cards, anonymous accounts with optional sign-in, Pro subscription with cloud sync and full stats, basic Wrapped.
- **Phase 2 — Retention:** trigger food detective, doctor report, duels, widgets, watch app, cosmetics store.
- **Phase 3 — Expansion:** leagues, health-app overlays, localization, and — only if the data supports it — broadening into a general gut-comfort tracker under the same brand.

---

## 7. Architecture — first launch (Flutter + Supabase pilot)

The pilot stack is right for this product; keep it. The one non-negotiable principle: **offline-first, local as the source of truth.** A tap must register in under 100 ms in airplane mode, in a basement, forever. The server is a sync target and stats engine, never a dependency of the core loop.

**Client (Flutter):**

- Local store: Drift (SQLite) with a single append-only `events` table — `{id (uuidv7), occurred_at, tags[], device_id, synced_at}`. Never update counts in place; derive everything from events. Meals are a second event type, not a separate system.
- A lightweight sync worker batches unsynced events to Supabase when online (upsert on client-generated UUIDs makes sync idempotent and conflict-free — last-write-wins is fine because events are immutable).
- All charts in the free tier compute locally, so the app is fully functional without an account.
- Haptics/animation on the raw gesture handler, not after the DB write — perceived latency is the product.

**Backend (Supabase):**

- **Auth:** start every user as a Supabase anonymous session; upgrade in place to Apple/Google/email when they buy Pro or join a duel. This kills sign-up friction without losing continuity of data.
- **Postgres:** `profiles`, `events`, `duels`, `duel_members`, with Row Level Security on everything (users read/write only their own rows; duel members read shared duel aggregates only). RLS is the whole security model — keep it airtight from day one.
- **Global stats:** a nightly (later hourly) `pg_cron` job rolls events into anonymous aggregate tables (`daily_global_stats`, percentile buckets). Clients read aggregates only — never raw population data. This is both a performance and a privacy decision.
- **Edge Functions:** doctor-report PDF generation, Wrapped card rendering (server-rendered PNG so cards look identical everywhere), and receipt-driven entitlement updates.
- **Payments:** RevenueCat over StoreKit/Play Billing. Do not hand-roll receipt validation; mirror entitlements into `profiles` via webhook → Edge Function.
- **Supporting:** Sentry for crashes, PostHog (or Amplitude) for product analytics — instrument the funnel from first tap → day-7 retention → paywall view → conversion from the very first build. Push via FCM/APNs, but earn it: notification permission is requested only after the first streak, never on first launch.

**Privacy posture (a launch feature, not a chore):** the data is silly *and* health-adjacent. Free tier can be 100% on-device — say so loudly. Cloud data is minimal, aggregates are anonymous, deletion is one tap and total, and there is no third-party ad SDK in the binary. This is a marketable differentiator and keeps App Store health-data review painless.

---

## 8. Architecture — expansion

What changes as Puff grows, roughly in the order it will hurt:

- **Events volume:** the `events` table grows fast (a hit means tens of millions of rows/month). Partition by month early, keep per-user rollup tables (`daily_user_stats`) maintained by triggers or the cron job so no chart ever scans raw events, and add read replicas when dashboards get heavy. This is standard Postgres scaling; Supabase handles it well before any re-platforming is justified.
- **Duels and leagues:** Supabase Realtime channels for live duel scores; server-side (Edge Function) validation of duel results to keep leaderboards honest. Add simple anti-cheat heuristics — a physical upper bound on plausible taps per hour is easy to enforce and funny to document.
- **Watch and widgets:** Flutter doesn't run on watchOS — the watch app is a small native SwiftUI companion talking to the phone app via WatchConnectivity, writing into the same local event store through a platform channel. Home-screen widgets via `home_widget` with an app-group-shared count. Wear OS can follow the same pattern later.
- **Wrapped at scale:** pre-compute Wrapped datasets in batch during the last week of the period; render cards through the Edge Function behind a CDN. Wrapped day is your peak-load event of the year — plan for 20× normal traffic.
- **Experimentation:** remote config + feature flags (PostHog flags are enough) for paywall copy, pricing tests, and staged rollouts. Price testing between $1.99 and $2.99 is worth real money; build the flag plumbing before you need it.
- **Team seams:** if any component eventually outgrows Supabase, it will be the stats/aggregation pipeline — it's already isolated behind aggregate tables, so it can move to a dedicated service without touching clients. Design every client API call against views/functions, not raw tables, to preserve that freedom.

---

## 9. Risks & guardrails

- **Health claims:** never diagnose, never alarm. All health copy is ranges and patterns with a standing "not medical advice" note. This keeps Puff out of medical-device territory and app-review trouble.
- **Store review:** the humor must stay PG — store metadata especially. "Toot" over harsher words everywhere user-facing; Gust and wind imagery keep the store listing clean.
- **Social abuse:** duel names and league names need a profanity filter and report flow before social ships.
- **The novelty cliff:** the joke fades in weeks; retention lives in streaks, duels, and the food detective. If week-4 retention is flat, invest in the GI-community features, not more jokes.
- **One-more-thing discipline:** the tap loop is the product. Any feature that adds a screen between the user and the button is wrong by default.

---

*Design tokens, mascot construction, components, and screen mockups: see `puff-design-book.html`. Questions about tone: when in doubt, ship the quieter option and the kinder joke.*
