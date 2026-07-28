# Puff — Live Detection & Duels: Technical Design

**July 2026 · Implements scopes A + B + C from [live-detection-analysis.md](live-detection-analysis.md)**

| Scope | What ships |
|---|---|
| **A** | Acoustic tag assist — the mic suggests Squeaky / Thunder / Windy on a manual tap |
| **B** | Listen mode — a deliberate foreground session that logs heard toots |
| **C** | Duels — **async** (tap-sourced, week-long) *and* **live** (heard-sourced, 3-minute rounds), both landing in Pro together |

Read the analysis first for *why*. This document is *how*: schemas, interfaces, migrations, file manifest, and build order.

---

## 0. Principles this design must not violate

Carried from [CLAUDE.md](../CLAUDE.md) and the handoff. Every decision below traces to one of these:

1. **Offline-first.** A tap registers in <100 ms in airplane mode. The mic, the model, the network — none of them may ever sit between the user and the counter.
2. **Events are append-only.** Never store or update counters. Everything derives.
3. **Heard ≠ tapped.** Acoustic events never enter the health log's headline numbers, streaks, badges, or world stats. This is an architectural line, not a preference.
4. **Gateways are interfaces.** Services take them by constructor; tests use fakes. No test touches a mic, a model, or a network.
5. **Silent failures aren't silent.** Every catch-and-carry-on site reports through `DiagnosticsService.record`.
6. **No hardcoded user-visible strings.** Everything through `app_en.arb`.
7. **The client only calls edge functions** — plus Auth, and now Realtime (a deliberate, documented addition; §4.5).

---

## 1. Shared foundation — `PuffEvent.source`

The single field both tracks depend on. **Build this first; both tracks are blocked on it and on nothing else.**

### 1.1 Domain

```dart
// lib/domain/puff_event.dart
/// How an event got logged. Tapped events are the health log — they feed
/// counts, streaks, badges and world stats. Heard events come from acoustic
/// detection: real logs, but never health data (a chair squeak must never
/// become a data point).
enum EventSource { tap, heard }

const String kSourceTap = 'tap';
const String kSourceHeard = 'heard';
```

`PuffEvent` gains `final EventSource source` (default `EventSource.tap`) and carries it through `copyWith`.

### 1.2 Query scoping — the safety mechanism

`EventStore`'s counting methods gain a filter that **defaults to tapped-only**, so every existing call site keeps its exact current semantics and heard events cannot silently leak into health numbers:

```dart
enum SourceFilter { tapped, heard, all }

Future<int> countForDay(DateTime day, {SourceFilter source = SourceFilter.tapped});
Future<Map<DateTime,int>> countsByDay({SourceFilter source = SourceFilter.tapped});
Future<List<PuffEvent>> eventsBetween(DateTime from, DateTime to,
    {SourceFilter source = SourceFilter.all});
```

Defaulting to `tapped` means the change is behaviour-preserving on day one (there are no heard events yet) *and* fail-safe forever after: a new caller that forgets to think about `source` gets the conservative answer.

**Binding rule:** `GlobalStatsService.reportIfDue` and everything feeding streaks/badges use `SourceFilter.tapped`. Only Listen mode, live duels and the Pro sound-signature stats pass `heard`.

### 1.3 Migrations

**Drift** — `schemaVersion` 1 → 2:

```dart
TextColumn get source => text().withDefault(const Constant('tap'))();

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) => m.createAll(),
  onUpgrade: (m, from, to) async {
    if (from < 2) await m.addColumn(events, events.source);
  },
);
```

**Supabase** — `0007_event_source.sql` (0006 is already taken by `api_grants`):

```sql
alter table events add column if not exists
  source text not null default 'tap' check (source in ('tap','heard'));
```

No RLS change: heard events are still the user's own events under the same policies. No new grant: `0006` already grants `events` to `authenticated`.

### 1.4 Sync

`SupabaseEventsSyncGateway` maps `source` in both directions. Old clients omit it and the column default fills in `'tap'` — forward- and backward-compatible.

---

## 2. Track 1 — Audio

### 2.1 Pipeline

```
record(16 kHz, PCM16, mono, AGC/NS/AEC OFF)
   │  20 ms frames
   ▼
┌─ ENERGY GATE ────────────────── main isolate, ~0 CPU ─┐
│  adaptive noise floor (rolling median of frame RMS)   │
│  onset when rms > floor * k for >= 2 frames           │
│  480 ms lookback ring buffer (never clip the attack)  │
└───────────────────────┬───────────────────────────────┘
                        │ onset → 0.975 s window (15600 samples)
                        ▼
┌─ CLASSIFIER ──────────────── background isolate, ~10 ms ─┐
│  YAMNet trunk (frozen)                                   │
│    → embedding [1,1024]  ─────► our head → p(toot)       │
│    → log-mel     [96,64]  ─────► signature features      │
└───────────────────────┬──────────────────────────────────┘
                        ▼
┌─ DECISION ────────────────────────── main isolate ─┐
│  p >= threshold (precision-biased, default 0.80)   │
│  refractory 1200 ms                                │
│  → AcousticDetection                               │
└────────────────────────────────────────────────────┘
```

**Why the gate matters:** the classifier runs only on onsets, so a quiet room costs approximately nothing and the mic capture dominates battery — which is why this is a session, not a background service.

### 2.2 Domain — `lib/domain/acoustic.dart` (pure Dart, fully unit-testable)

```dart
/// What the acoustics say about one detected sound.
class AcousticSignature {
  final double peakDb;         // -100..0, loudness
  final double fundamentalHz;  // F0 estimate, 0 when inharmonic
  final double harmonicRatio;  // 0..1, tonal vs. noisy
  final Duration duration;
}

/// One confirmed detection.
class AcousticDetection {
  final DateTime at;
  final double confidence;     // head output, 0..1
  final AcousticSignature signature;
}

/// Maps acoustics onto the design book's tag vocabulary. Pure function —
/// this is the whole of Design A's intelligence and it is trivially testable.
/// Returns null when nothing reads clearly; a suggestion is never forced.
String? suggestedTag(AcousticSignature s);
```

Rules (tuned against the eval set, not invented at the keyboard — these are the starting point):

| Tag | Condition |
|---|---|
| `thunder` | `peakDb > -12 && fundamentalHz < 120 && duration > 800 ms` |
| `squeaky` | `fundamentalHz > 180 && harmonicRatio > 0.5` |
| `windy` | `harmonicRatio < 0.3` |
| *(none)* | otherwise |

`silent` / `sbd` are **never** suggested — they're acoustically undetectable by definition, and pretending otherwise would be a lie the product tells about itself.

### 2.3 Gateways — added to `lib/data/gateways.dart`

```dart
/// Raw microphone access. Emits 16 kHz mono PCM16 frames.
abstract class AudioCaptureGateway {
  Future<bool> hasPermission();
  Future<bool> requestPermission();
  Stream<Int16List> start();
  Future<void> stop();
}

/// The acoustic model. Implementations load YAMNet + our head; the fake
/// returns scripted verdicts so services are testable without a model.
abstract class AcousticClassifier {
  Future<void> load();
  Future<AcousticVerdict> classify(Float32List window);  // 15600 samples
  Future<void> dispose();
}

class AcousticVerdict {
  final double confidence;
  final AcousticSignature signature;
}
```

Both get fakes in `test/fakes.dart`: `FakeAudioCaptureGateway` (scriptable frame stream, permission toggles) and `FakeAcousticClassifier` (queued verdicts). **No test opens a mic or loads a model.**

### 2.4 `ListenService` — `lib/services/listen_service.dart`

```dart
enum ListenState { idle, permissionDenied, starting, listening, error }

class ListenService extends ChangeNotifier {
  ListenService(this._capture, this._classifier, this._tap, this._settings, {
    required this.onError,           // → DiagnosticsService.record
    DateTime Function()? clock,
  });

  ListenState get state;
  double get level;                  // 0..1, for the meter
  int get sessionCount;
  List<AcousticDetection> get sessionDetections;
  Duration get sessionElapsed;
  Duration? get remainingBudget;     // null = unlimited (Pro)

  Future<void> startSession({required ListenMode mode});
  Future<void> stopSession();
  Future<void> undoLast();           // deletes the event, corrects the count

  /// Design A: the most recent detection within [window], or null.
  AcousticDetection? recentDetection({Duration window = const Duration(seconds: 5)});
}

enum ListenMode { assist, session, duel }
```

- **Writes go through `TapService.logHeard(detection)`**, not directly to the store — one place owns event creation, and the optimistic-count discipline stays intact.
- **Free-tier budget** lives here: `remainingBudget` counts down; at zero the session ends and the paywall sheet opens.
- Every failure path (permission denied, capture error, model load failure, isolate crash) calls `onError` → Diagnostics.

### 2.5 Design A — tag assist

Deliberately the smallest possible change to the core loop:

1. `ListenService` runs in `ListenMode.assist` **only** while Home is the visible tab, the setting is on, and permission is granted. It writes **no events** in this mode.
2. `QuickTagsRow` reads `listen.recentDetection()` during the quick-tag window and marks the suggested chip with a subtle outline + a small mic glyph.
3. **The suggestion never writes.** The user still taps the chip. A wrong suggestion costs nothing; an auto-written wrong tag would corrupt the log.

This preserves the tap loop exactly: haptics and animation still fire on the raw gesture, `TapService.tap()` is unchanged, and the mic is never in the write path.

### 2.6 Design B — Listen mode screen

`lib/presentation/screens/listen_screen.dart`, pushed full-screen from a mic pill on Home.

```
┌──────────────────────────────┐
│  ←            0:42    ●REC   │   elapsed + budget
│                              │
│         ☁︎  Gust             │   scales/pulses with level
│        (reacting)            │   coral flash on detection
│                              │
│           7                  │   session count, Baloo 2
│      heard this session      │
│                              │
│   ▁▂▅█▅▂▁▁▂▃▁               │   level meter
│                              │
│   ┌────────────────────────┐ │
│   │ 12:04:31  thunder   ↶ │ │   detection list, newest first,
│   │ 12:04:12  squeaky   ↶ │ │   each with undo
│   └────────────────────────┘ │
│                              │
│        [  Stop  ]            │
└──────────────────────────────┘
```

- Reduced motion: Gust's scale animation off, colour pulse stays, haptic always fires (existing invariant).
- Free tier: budget chip counts down; on exhaustion → `PaywallSheet`.
- Never blocks: if permission is denied the screen explains and offers Settings, and **Home still works normally**.

### 2.7 Model pipeline

Not shipped code — the offline pipeline that produces the two assets.

```
tool/acoustic/
  harvest.mjs     Freesound API, filter license:"Creative Commons 0"
  augment.py      RIR convolution, MUSAN noise, SpecAugment, phone-chain sim
  train.py        YAMNet trunk (frozen) → embeddings → head (2-layer MLP)
  eval.py         precision/recall on a held-out real-room set
  convert.py      yamnet.h5 → yamnet.tflite  (from the Apache-2.0 repo)
```

Ships as:

| Asset | Size | Notes |
|---|---|---|
| `assets/acoustic/yamnet.tflite` | ~4 MB | Apache-2.0, converted by us from `tensorflow/models` |
| `assets/acoustic/head.bin` | ~50 KB | ours; shippable independently of the trunk |
| `assets/acoustic/NOTICE` | — | Apache attribution, registered via `LicenseRegistry` |

**Train/serve parity is a hard requirement:** the corpus must be recorded through the same capture settings used at inference (16 kHz, AGC/NS/AEC off). Mismatch here is the classic silent failure mode.

### 2.8 `HeuristicClassifier` — the interim stand-in

`YamnetClassifier` cannot work until `head.bin` exists, and that needs the spike plus a labelled corpus. So `HeuristicClassifier` implements the same interface with plain DSP (autocorrelation pitch, envelope duration, peak level) and **no model**.

It is explicitly the approach §3 rejected — energy and pitch can't separate a toot from a chair squeak — and it must never ship as the detector. Guardrails:

- selected only under `--dart-define=PUFF_ACOUSTIC_HEURISTIC=true`; production builds get `YamnetClassifier`
- `maxConfidence` caps its output at 0.92, so it never reads as certain

It has one lasting use beyond unblocking M3/M4 on real hardware: **it is the baseline the spike measures against.** If the trained head can't beat it, the head isn't ready.

---

## 3. Track 2 — Duels

### 3.1 Tables — `0008_duels.sql`

```sql
create table duels (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,          -- 6 chars, A-Z2-9 (no I/O/0/1)
  kind        text not null check (kind in ('async','live')),
  name_adj    smallint not null,             -- indices into the curated
  name_noun   smallint not null,             -- wordlist — see §3.4
  created_by  uuid not null default auth.uid() references auth.users(id) on delete cascade,
  starts_at   timestamptz not null,
  ends_at     timestamptz not null,
  status      text not null default 'open' check (status in ('open','running','settled')),
  created_at  timestamptz not null default now()
);

create table duel_members (
  duel_id   uuid not null references duels(id) on delete cascade,
  user_id   uuid not null default auth.uid() references auth.users(id) on delete cascade,
  handle    smallint not null,               -- index into the same wordlist
  joined_at timestamptz not null default now(),
  primary key (duel_id, user_id)
);

create table duel_scores (
  duel_id    uuid not null references duels(id) on delete cascade,
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  tapped     int not null default 0,
  heard      int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (duel_id, user_id)
);
```

`duel_scores` is a **submission**, not a derived counter — the server has no raw events for free users, so scores are client-submitted and server-validated (§3.5). It doesn't violate the append-only rule, which governs the *event log*.

### 3.2 RLS

The predicate everything hangs off:

```sql
create function is_duel_member(d uuid) returns boolean
language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from duel_members
    where duel_id = d and user_id = (select auth.uid())
  );
$$;
```

| Table | select | insert | update |
|---|---|---|---|
| `duels` | `is_duel_member(id)` | own `created_by` **and** `has_active_pro()` | creator only |
| `duel_members` | `is_duel_member(duel_id)` | own row only | — |
| `duel_scores` | `is_duel_member(duel_id)` | own row only | own row only |

**Pro gate lives on `duels` INSERT** — creating is Pro, joining is free (the handoff's rule: the invited person is the acquisition). Enforced in Postgres, not the client. Plus explicit grants in the same migration, per the `0006` precedent.

### 3.3 Edge function — `functions/duels/index.ts`

One function, action-dispatched (mirrors `entitlements`):

| Method / action | Does |
|---|---|
| `GET` | List my duels + members + scores |
| `GET ?code=XXXXXX` | Preview a duel before joining |
| `POST {action:'create'}` | Create (RLS Pro-gates), generate code, seat creator |
| `POST {action:'join'}` | Join by code; enforces free-tier one-duel limit |
| `POST {action:'score'}` | Submit `{tapped, heard}` — **validated**, §3.5 |
| `POST {action:'leave'}` | Remove own membership |

All through `userClient(req)`. No service_role. Errors map through the existing `errorStatus` (42501 → 403).

### 3.4 Names — deleting the moderation surface

TODO.md lists *"profanity filter and report flow"* as a hard blocker before any social ships. This design **removes the blocker rather than mitigating it**: duel names and player handles are **not free text and cannot be**.

The DB stores `smallint` indices; the client renders from a curated l10n wordlist:

```
adjectives: breezy, gusty, silent, thunderous, whispering, drafty, …
nouns:      badgers, storms, gales, whirlwinds, zephyrs, drafts, …
→ "Breezy Badgers"   with a reroll button
```

Free text is **structurally impossible** — there is no column to put it in. No filter to bypass, no report queue, no store-review risk, and the names are funnier than what users would type. `safe_text` + a report flow stay in reserve for if custom names ever ship as a Pro cosmetic.

### 3.5 Anti-cheat

Per the handoff's *"physical upper bound on plausible taps per hour"*, validated server-side in the `score` action:

- **Async duels** score `tapped` only. Cap: 40/hour and 300/day over the duel window; submissions above the cap clamp and record a flag.
- **Live duels** score `heard` only, and are explicitly **honour-system party mode** (§12 of the analysis) — a mouth raspberry beats any classifier, so the anti-cheat here is social, not technical. Round length caps the damage anyway.
- Scores are monotonic per duel: a submission may never *decrease* a score, which kills replay/rollback games.

---

## 4. The join — Design C, live duels

### 4.1 Flow

```
Pro creates live duel → code shown
       ↓ (code shared over any chat app — no deep-link infra)
Opponent joins by code
       ↓ both tap "Ready"
3-minute round, both phones in Listen mode
       ↓ throttled broadcast every 2 s
Live scoreboard; opponent rendered optimistically between updates
       ↓
Round ends → final score submitted via edge fn → winner share card
```

### 4.2 Realtime — and its hard budget

From the analysis: **Pro = 500 concurrent connections / 500 msg/s → 250 simultaneous live duels.** The design must respect that from day one:

- Channel `duel:<id>`, **private** (`config: {private: true}`).
- **Broadcast one coalesced `{count}` every 2 s per client** — never per detection. At 250 concurrent duels that's 250 msg/s, comfortably inside the 500 ceiling with headroom.
- Presence used once at join/leave only (the 5-calls-per-30 s cap is easy to trip with anything chattier).
- Final scores go through the **edge function**, not Realtime — broadcast is for liveness, the function is for truth.

### 4.3 Realtime authorization

Private channels authorize through RLS on `realtime.messages`, in `0009_realtime_authz.sql`:

```sql
create policy "duel channel: members read"
  on realtime.messages for select to authenticated
  using (
    realtime.messages.extension in ('broadcast','presence')
    and is_duel_member(substring(realtime.topic() from 6)::uuid)
  );
-- matching insert policy for write
```

Requires disabling "Allow public access" in Realtime settings — a **deployment step**, documented in `supabase/README.md`.

This is the one place the client touches Supabase outside an edge function, alongside Auth. Authorization still lives entirely in RLS, so it's consistent with "RLS is the whole security model" — but it *is* a change to the stated convention and CLAUDE.md must say so.

---

## 5. File manifest

**New — mobile**

```
lib/domain/acoustic.dart                     signature, detection, suggestedTag
lib/domain/duel.dart                         Duel, DuelMember, DuelScore, name rendering
lib/data/acoustic/yamnet_classifier.dart     flutter_litert impl + isolate
lib/data/acoustic/heuristic_classifier.dart  DSP-only dev stand-in (see below)
lib/data/acoustic/record_capture.dart        record impl
lib/data/supabase/supabase_duel_gateway.dart edge-fn client
lib/services/listen_service.dart             sessions, cascade orchestration
lib/services/duel_service.dart               duel state, Realtime, throttled broadcast
lib/presentation/screens/listen_screen.dart
lib/presentation/screens/duel_detail_screen.dart
lib/presentation/widgets/level_meter.dart
lib/presentation/widgets/detection_list.dart
assets/acoustic/{yamnet.tflite, head.bin, NOTICE}
tool/acoustic/{harvest,augment,train,eval,convert}
```

**Modified — mobile**

```
lib/domain/puff_event.dart      + EventSource
lib/data/event_store.dart       + SourceFilter on counting methods
lib/data/drift/*                schema v2 + migration
lib/data/gateways.dart          + AudioCaptureGateway, AcousticClassifier, DuelGateway
lib/services/tap_service.dart   + logHeard()
lib/services/stats_service.dart source-scoped; + sound-signature stats (Pro)
lib/presentation/screens/home_screen.dart      + mic pill
lib/presentation/widgets/quick_tags_row.dart   + suggestion marker
lib/presentation/screens/duels_screen.dart     teaser → real list
lib/app.dart, lib/main.dart     new providers
lib/l10n/app_en.arb             ~60 new keys
pubspec.yaml                    record, flutter_litert, permission_handler; assets
```

**New — supabase**

```
migrations/0007_event_source.sql
migrations/0008_duels.sql
migrations/0009_realtime_authz.sql
functions/duels/index.ts
```

---

## 6. Testing

Everything against fakes — no mic, no model, no network, per the existing convention.

| Suite | Covers |
|---|---|
| `domain_test.dart` (extend) | `suggestedTag` truth table incl. never-suggest-silent; duel name rendering |
| `listen_service_test.dart` | onset→verdict→detection; threshold rejection; refractory; budget exhaustion; permission denial → diagnostics; undo |
| `tap_service_test.dart` (extend) | `logHeard` doesn't touch today's tapped count |
| `stats_service_test.dart` | heard events excluded from streaks/badges/week chart; included in signature stats |
| `duel_service_test.dart` | join/score/settle; monotonic scores; broadcast throttling (fake clock) |
| `sync_service_test.dart` (extend) | `source` round-trips |

---

## 7. Build order

| # | Milestone | Gate |
|---|---|---|
| **M0** | `PuffEvent.source` end to end | Both tracks unblocked |
| **M1** | Audio domain + gateways + `ListenService` on fakes | Logic proven without hardware |
| **M2** | Real capture + YAMNet classifier + isolate | Spike's precision confirmed on-device |
| **M3** | **A** — tag assist | First user-visible audio feature |
| **M4** | **B** — Listen mode | Free-tier delight + paywall moment |
| **M5** | Duels backend (0008, 0009, edge fn) | `supabase db reset` clean |
| **M6** | Async duels UI | Pro's retention mechanic live |
| **M7** | **C** — live duels | The prize |

M1–M4 and M5–M6 are independent after M0 and can run in parallel; M7 needs both.

---

## 8. Deployment checklist

- [ ] `supabase db push` — 0007, 0008, 0009
- [ ] `supabase functions deploy duels`
- [ ] **Disable "Allow public access" in Realtime settings** (required for §4.3)
- [ ] Android: `RECORD_AUDIO` in the manifest; confirm `minSdk >= 26` (LiteRT)
- [ ] Register the YAMNet Apache-2.0 NOTICE via `LicenseRegistry`; surface at You → Settings → About
- [ ] Privacy note updated: mic is foreground-only, audio never leaves the device, contribution opt-in is default-off
- [ ] No foreground-service type declared — foreground-only by design
