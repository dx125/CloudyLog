# Puff — Live Detection ("Listen mode") Feature Analysis

**July 2026 · Companion to [puff-handoff.md](puff-handoff.md) and the Design Book**

Recognise toots acoustically while the app is in the foreground, count those separately from tapped events, and use them to power *live* competition instead of blind button-mashing.

This document works the problem end to end: is it detectable, model vs. no model, which models, what we may legally ship, how we'd train, the technical path in this codebase, product shapes, and monetization.

**Status: approved for build.** Scope is **A (tag assist) + B (Listen mode) + C (duels — async *and* live, both landing together in Pro)**. §13 carries the verified technical decisions from the final research pass and the build plan; §10–12 have been revised to match the committed scope.

---

## 1. TL;DR

**Feasible, with a clean commercial licence path.** Google's **YAMNet** is Apache-2.0 and already ships an AudioSet class literally named `Fart` (index 55, `/m/02_nn`). It's 3.7 M params, ~4 MB, runs in ~10 ms per frame on any phone. We can prototype zero-shot this week without a single line of training code.

**The hard part is not detection — it's discrimination and trust.**

1. **False positives are the product risk.** Chair squeaks, shoe scuffs, lip raspberries and balloon noises are acoustically near-identical. A phantom detection in a quiet room full of friends is exactly the moment someone screenshots for a 1-star review. Tune for **precision over recall**, always.
2. **Acoustic verification is not verification.** A mouth raspberry beats any classifier we can ship. Live duels therefore must be **honour-system party mode**, never a verified ledger — and heard events must never contaminate the health log or world stats.
3. **"Silent but deadly" is undetectable by definition.** Own it in the copy; it's a free joke.
4. **Training data is the real cost centre**, and the only durable moat. Nobody else has a labelled corpus of this.

**Build order (approved):** two parallel tracks — **audio** (tag assist → Listen mode) and **duels** (async duels → live duels) — converging at live duels. Neither track blocks the other until the join. See §13.4.

**Stack (verified):** `record` (PCM16 stream, *all* speech DSP disabled — §13.2) → energy gate in Dart → YAMNet trunk (Apache-2.0, frozen) + our own trained head, in a background isolate via **`flutter_litert`** (not `tflite_flutter` — §13.2). 100% on-device. No audio ever leaves the phone except through an explicit, default-off training-contribution opt-in.

---

## 2. Is a toot acoustically detectable?

### 2.1 The signal

The sphincter acts as a vibrating aperture — a quasi-periodic buzz plus broadband turbulent noise.

| Property | Typical range | Note |
|---|---|---|
| Duration | 0.2 – 3 s | Longer than a click, shorter than speech |
| Fundamental (F0) | ~60 – 250 Hz | Strongly harmonic when tonal ("squeaky") |
| Energy concentration | < 2 kHz | With significant turbulence to 4–8 kHz |
| Envelope | Sharp onset, variable decay | Onset detection is easy |
| Loudness | Wide dynamic range | The quiet tail is where recall dies |

The design book's own tag vocabulary maps neatly onto measurable acoustics — which is itself a product opportunity (§7.1):

- **Squeaky** → higher F0, high harmonic-to-noise ratio, short
- **Thunder** → low F0, high energy, long, broadband
- **Windy** → noise-dominant, low harmonicity
- **Silent / SBD** → **no acoustic signature at all. Permanently undetectable.**

### 2.2 The confusion set — this is the whole problem

Ranked by how badly each will hurt us:

| Confusor | Why it's hard | Threat |
|---|---|---|
| **Lip raspberry / mouth fart** | Physically the same mechanism (buzzing aperture). Essentially indistinguishable. | **Cheating vector #1.** Unsolvable acoustically. |
| **Chair / seat squeak** (leather, vinyl, gym bench) | The classic. Same band, same envelope, same duration. | **False-positive #1.** Embarrassing in public. |
| Shoe squeak on a gym floor | Same as above | High |
| Whoopee cushion, balloon deflation | Deliberately imitative | Medium (mostly benign — user is joking) |
| Door hinges, drawer friction | Similar transient buzz | Medium |
| Blowing on the mic, wind, pocket rustle | Broadband, high energy | High, but easy to gate on spectral flatness |
| Bass transients from music/TV | Low-band energy spikes | Medium — handled by harmonic structure |
| Plumbing, coffee-machine steam | Turbulent noise | Low |

**Design consequence:** the classifier's job is *discrimination against this list*, not "is there a sound". That dictates the whole training-data strategy (§6) — we need far more hard negatives than positives.

### 2.3 Prior art

Bowel/GI acoustics is a live research area — Georgia Tech's toilet-acoustics work, and 2026 benchmarking of bowel-sound classification reaching ~0.89 AUC with pretrained speech models (HuBERT) on data from 16 subjects. Two takeaways: (a) pretrained-audio-model transfer learning is the established method for exactly this class of problem, and (b) published work uses *contact* microphones on the abdomen, not a phone across the room. Our SNR is materially worse than the literature's. Don't quote their accuracy numbers at ourselves.

---

## 3. Model vs. no model

| | Approach | Ship-ability | Verdict |
|---|---|---|---|
| **A** | **Pure DSP heuristics** — onset detection, band-energy ratios, spectral flux/flatness, ZCR, duration gate | Tiny (~0 KB, ~0 CPU), zero licensing, fully explainable, trivially tunable. But it *cannot* separate a toot from a chair squeak — they share the coarse spectral envelope. Expect ~60–75 % precision in a quiet room, collapsing in the real world. | ❌ Not shippable as "recognition"… ✅ …but **essential as stage 1 of the cascade** (§5.1) |
| **B** | **Pretrained tagger, zero-shot** — YAMNet's `Fart` class straight out of the box | Zero training data, zero legal work, ~4 MB, real-time anywhere. But AudioSet's `Fart` class is *rare*: **1,231 clips / 3.3 h total** (61 eval, 1,110 unbalanced-train), weakly labelled, and YAMNet's overall balanced mAP is only 0.306. Recall on loud clean events should be decent; precision against raspberries and squeaks will be poor, because nothing in its training emphasised those confusions. | ⚠️ **Ship as the v0 bootstrap and data-collection engine — not as the final quality bar** |
| **C** | **Transfer learning on frozen embeddings** — YAMNet trunk → 1024-d embedding → our own small head (logreg / 2-layer MLP / tiny GRU), trained on our data with the confusion set as explicit negatives | The standard, cheap, effective method. A few hundred–few thousand labelled clips trains in minutes on a laptop. Head is ~50 KB, so we can ship model improvements without re-shipping the trunk. **Licence story is spotless** (Apache-2.0 trunk + data we own). | ✅ **The recommendation** |
| **D** | **Full fine-tune / bigger backbone** — AST, BEATs, PANNs CNN14, HuBERT | Higher ceiling, but 10–90 M params, needs quantisation, needs 10× the data, heavier on battery, and the weight licences get muddier. | 🕒 Only if C plateaus. Not the launch path. |
| **E** | **Cloud inference** | Breaks the offline-first non-negotiable, adds latency that kills the live feel, costs per user-hour, and streaming raw mic audio off a *fart-tracking app* is a privacy and App Store review catastrophe. | ❌ **Hard no** for the detection path |

**Answer to "do we need to train a model?":** we need to train a *head*, not a model. That's a meaningfully smaller commitment — a few days of ML work, on top of a data-collection effort that is the actual project.

---

## 4. Model comparison & commercial licensing

### 4.0 Is YAMNet safe for a commercial app? — **Yes.** Verified at three levels.

| Evidence | Source |
|---|---|
| Repository licence is Apache License **2.0** | [`tensorflow/models/LICENSE`](https://raw.githubusercontent.com/tensorflow/models/master/LICENSE) |
| Per-file header on the model source itself: *"Copyright 2019 The TensorFlow Authors All Rights Reserved. Licensed under the Apache License, Version 2.0"* | [`yamnet.py`](https://raw.githubusercontent.com/tensorflow/models/master/research/audioset/yamnet/yamnet.py) |
| Weights are published by Google as part of that same Apache-2.0 project | [YAMNet README](https://github.com/tensorflow/models/tree/master/research/audioset/yamnet) |

**What Apache 2.0 grants us**, specifically for this use:

- ✅ **Commercial use** — no royalties, no revenue share, no approval, no notification
- ✅ **Redistribution in object form** — i.e. shipping the converted `.tflite` inside our APK/IPA is explicitly permitted (§4)
- ✅ **Modification** — quantising it, converting it, freezing the trunk and bolting our own head on are all fine, and **our head is entirely ours** (Apache 2.0 imposes no copyleft; derivative works may be licensed however we like)
- ✅ **Express patent grant** (§3) — materially better than MIT here, which is silent on patents
- ✅ **No field-of-use restriction, no acceptable-use policy, no model-card conditions**

**What we must do in return** (all trivial):

1. Include a copy of the Apache 2.0 licence text with the distribution
2. Retain the copyright/attribution notices
3. State that we modified the file, if we ship a modified one

In Flutter this is satisfied by registering the licence with `LicenseRegistry.addLicense(...)` so it appears in the standard `showLicensePage` — which the app should surface from **You → Settings → About** anyway.

**One procedural recommendation:** source the weights from the Apache-2.0 repo itself (`storage.googleapis.com/audioset/yamnet.h5`) and run the TFLite conversion ourselves, rather than downloading a pre-converted `.tflite` from Kaggle Models or a random GitHub fork. Same artefact, but the provenance chain stays entirely inside one clearly-licensed Google repository, with no third-party hosting terms and no unknown fork's modifications layered in. Check the converted model into the repo as a build artefact with its provenance documented.

**The one thing to avoid:** don't copy the AudioSet **ontology** (class-name taxonomy) verbatim into the product — it's CC-BY-**SA** 4.0 and share-alike would be an unwelcome guest. We only need index 55 anyway, mapped to our own label string. See §4.1.

> Not legal advice — but as software-licensing questions go, this one is about as clean as they come. Apache 2.0 is the licence Google uses precisely so that people can ship this in products.

---

Licences verified against primary sources.

| Model | Params | Licence | Commercial? | Notes |
|---|---|---|---|---|
| **YAMNet** (Google, MobileNetV1) | 3.7 M | **Apache 2.0** (`tensorflow/models` LICENSE) | ✅ **Yes — clean.** Sublicensable, patent grant, just needs a NOTICE attribution | 521 classes incl. `Fart` (55), `Burping, eructation` (53), `Stomach rumble` (52). 16 kHz mono, 0.975 s frames, 1024-d embedding, ships as TFLite. 69.2 M multiplies/frame. **Recommended.** |
| **PANNs CNN14** (Kong et al.) | ~80 M | **CC-BY** (Zenodo release) | ⚠️ Permitted with attribution, but CC licences on model weights are legally awkward (Creative Commons itself discourages CC for software), and 80 M params is heavy for a phone | Higher mAP (0.431). Good as an *offline labelling/teacher* model even if we don't ship it. |
| **AST** (MIT CSAIL) | ~87 M | Code BSD-ish; weights AudioSet-derived | ⚠️ Ambiguous | Too heavy for on-device anyway |
| **BEATs** (Microsoft) | ~90 M | MIT code, weights ambiguous | ⚠️ Needs legal review | Strong, but not worth the ambiguity |
| **Apple SoundAnalysis** (`SNClassifySoundRequest`) | n/a | OS framework | ✅ Free to call on iOS | 300+ built-in classes. **iOS only** — and the built-in set is not guaranteed to contain our class, so it can't be the cross-platform path. Worth a probe as a free iOS second opinion. |
| **Custom small CNN from scratch** | ~0.1–1 M | Ours | ✅ Total freedom | Needs 10–100× more data than transfer learning. Not worth it. |

### 4.1 Dataset licensing — the trap

| Source | Licence | Usable for our training? |
|---|---|---|
| **AudioSet annotations** | CC-BY 4.0 | ✅ Labels only |
| **AudioSet ontology** (class names/hierarchy) | **CC-BY-SA 4.0** | ⚠️ **Share-alike.** Don't copy the taxonomy verbatim into the product — map index 55 to *our own* label string and we're clear |
| **AudioSet audio** | **Not distributed.** YouTube IDs only; downloading conflicts with YouTube ToS | ❌ **Do not scrape.** This is the single biggest legal exposure in the naive approach |
| **FSD50K** | Per-clip mix: CC0 / CC-BY / **CC-BY-NC** / Sampling+ | ⚠️ Usable **if filtered to CC0 + CC-BY only**, with per-clip licence tracking |
| **Freesound** (direct query) | Per-clip, filterable to CC0 | ✅ **Best free commercial-safe source** |
| **ESC-50** | CC BY-**NC** | ❌ Non-commercial. Avoid entirely |
| **MUSAN** (noise/augmentation) | CC-BY | ✅ Good for negative/background augmentation |

**The key insight:** using a *model someone else trained on AudioSet* is fine — Google granted us Apache-2.0 rights to the weights. Training *our own* model on AudioSet audio would require obtaining that audio, which we can't do cleanly. This is another argument for the frozen-trunk approach (C): it puts the AudioSet exposure entirely on Google's side of the licence line.

---

## 5. Technical path

### 5.1 The cascade

Three stages, each more expensive than the last, so the expensive one almost never runs:

```
mic (16 kHz PCM16, 20 ms frames)
  │
  ├─ Stage 1 · ENERGY GATE            [Dart, ~0 CPU, every frame]
  │    adaptive noise floor + onset detection + duration plausibility
  │    → rejects ~99 % of wall-clock time
  │
  ├─ Stage 2 · CLASSIFIER             [isolate, ~10 ms, only on onset]
  │    480 ms lookback ring buffer (never clip the attack)
  │    → YAMNet trunk → 1024-d embedding → our head → p(toot)
  │
  └─ Stage 3 · DECISION               [Dart]
       threshold (precision-biased) + refractory period + optional
       second-frame confirmation
       → PuffEvent(source: 'heard') + haptic + Gust reaction
```

**Latency budget:** onset → confirmed → visible feedback in **< 250 ms**. That is live enough to feel like competition.

### 5.2 Packages

See §13.2 for the verified decisions and version numbers. In short: `record` v7 for capture (with all speech DSP **off**), `flutter_litert` for inference (**not** `tflite_flutter`, which is stale), and a mandatory background isolate — the tap loop's sub-100 ms guarantee must never share a thread with inference.

### 5.3 Battery

YAMNet run *continuously* is ~0.07 GMAC/s — negligible. **The mic capture is the drain**, roughly 3–8 %/hour on a modern phone. This is why live detection is a **session/mode**, not an always-on background service — which conveniently is also what store policy (§8) and the handoff's "one-more-thing discipline" want.

### 5.4 Fit with this codebase

Respecting the existing invariants:

| Layer | Change |
|---|---|
| `lib/domain/puff_event.dart` | Add **`source`** field (`'tap'` \| `'heard'`), defaulting to `'tap'`. **Not** a new `type` — `type` means *what happened* (toot vs. meal); `source` means *how we learned about it*. Keeps events append-only and everything still derived. |
| `lib/domain/` | New `acoustic_signature.dart` — pure-Dart mapping of confidence + spectral features → suggested tag |
| `lib/data/gateways.dart` | `AudioCaptureGateway` + `AcousticClassifier` **interfaces** (per the repo's DI convention), so tests use fakes from `test/fakes.dart` and no test touches a mic |
| `lib/data/drift/` | Migration: `source` column. Schema version bump. |
| `lib/services/listen_service.dart` | Session lifecycle, permission, cascade orchestration, isolate management. Emits detections into `TapService`. |
| `lib/services/stats_service.dart` | Filter/split by `source` — **heard events stay out of the health log's headline numbers and out of `report-stats`** |
| `supabase/migrations/` | `0006_event_source.sql` — add `source` to `events`, keep RLS unchanged |
| Diagnostics | Permission denials, mic failures, isolate crashes **must** go through `DiagnosticsService.record` (existing invariant) |
| l10n | Every string into `app_en.arb`; regenerate |
| Motion | Reduced-motion rules apply to the live level meter and Gust reactions; haptic always fires |

**Critical invariant to add:** heard events never feed `user_daily_stats` / world aggregates. World stats are the app's one claim to health legitimacy — a population number polluted by chair squeaks and raspberries is worthless.

---

## 6. Training-data strategy

This is the project's real cost, and its only moat.

**1 · Seed corpus (week 1).** Freesound filtered to CC0/CC-BY: fart, flatulence, raspberry, whoopee cushion, chair squeak, door hinge, balloon. A few hundred clips. Plus deliberately recorded negatives — sit on every chair in the office and record it.

**2 · Hard negatives outnumber positives 3–5×.** The model's job is discrimination (§2.2). Weight the corpus toward the confusion set, not toward more examples of the obvious case.

**3 · Augmentation multiplies a small corpus 20–50×.** Room impulse responses, additive noise (MUSAN, CC-BY), SpecAugment, gain/pitch/time-stretch, and — importantly — **simulate the phone signal chain**: band-limiting, AGC, codec artefacts. Models trained on clean studio audio fall apart on a phone in a pocket.

**4 · The in-app flywheel (the moat).** When the detector fires, Listen mode already shows a confirm/dismiss affordance for UX reasons. That interaction *is* a label. A default-**off**, explicitly opt-in "help train Puff" setting uploads the 2 s clip + label. Within a few months this is a labelled corpus nobody can replicate.

**5 · Non-negotiable privacy rules for that flywheel:**
- Opt-in, default OFF, per-feature — never bundled into a general "analytics" toggle
- Plain-language disclosure at the moment of opt-in, not buried in a policy
- Only the ~2 s window around a detection, never continuous audio
- Stated retention period; deletion request wipes contributed clips too
- Excluded from anything classified as health data
- Ships through an Edge Function like everything else (repo convention: no direct table access)

The handoff calls privacy "a launch feature, not a chore". Microphone access is where that promise gets tested hardest.

---

## 7. Product design options

The handoff's binding constraint: *"any feature that adds a screen between the user and the button is wrong by default."* Live detection must not touch the core tap loop.

### 7.1 Design A — Acoustic tag assist *(smallest, best value-per-risk)*

When the user taps manually, if the mic caught something in the preceding few seconds, pre-select the tag: Squeaky / Thunder / Windy. Uses the same 10 s quick-tag window that already exists.

- **Adds no screen.** Improves the loop we already have.
- Failure mode is *harmless* — a wrong tag suggestion is a shrug, not an embarrassment.
- Requires the mic only while Home is foregrounded, and only briefly.
- **This is the highest-value, lowest-risk entry point, and it doubles as the data-collection vehicle for everything else.**

### 7.2 Design B — Listen mode *(the headline feature)*

A mic pill on Home (or in Duels) opens a deliberate full-screen session: Gust reacting live, a level meter, count ticking up, confirm/dismiss on each detection. Ends on tap or timeout.

- Explicit entry = clean permission story, clean battery story, clean policy story
- Full-screen means the live Gust animation can be genuinely delightful — this is the screenshot
- Confirm/dismiss makes false positives *recoverable* instead of infuriating

### 7.3 Design C — Live duels / "Puff-off" *(the reason to build any of this)*

Two phones both in Listen mode, joined to a shared session over Supabase Realtime. Live scoreboard, 3-minute round, winner share card.

- Genuinely novel; nothing like it exists
- Inherently viral — needs a second person, and generates a share card (the handoff's #1 growth mechanic)
- **Blocked:** duels don't exist yet (Phase 2; the tab is a "coming soon" teaser)
- **Must be framed as honour-system party mode.** A raspberry beats the classifier and always will. Anti-cheat here is *social* (you're in the same room, people are watching), not technical. Never claim verification we can't deliver.

### 7.4 Design D — Ambient / passive session

Long-running listening (an afternoon, overnight) for passive logging.

- Highest genuine value for the GI audience — passive symptom logging is the holy grail of the food-diary problem
- **But:** hardest on battery, policy, and privacy simultaneously. Needs an Android foreground service with type `microphone` (which requires a Play Console declaration *plus* a demonstration video), and "always-listening fart app" is a headline waiting to happen.
- **Defer.** Revisit only if Listen mode's precision proves excellent and the GI cohort asks for it.

### 7.5 Copy notes

- **Own the SBD gap:** "Puff can't hear the silent ones. Nobody can. Tap those in." One joke, on brand, and it manages expectations.
- **Own the misses:** a missed detection should read as Puff's fault, lightly — "didn't catch that one?" with a tap affordance. Never make the user feel unheard.
- Voice rules still apply: cheeky never crude, one joke per screen, "toot" everywhere.

---

## 8. Store & policy risk

- **Microphone permission on a fart app will attract review scrutiny.** Mitigations: an explicit, honest purpose string; foreground-only at launch; no audio leaving the device by default; no background service.
- **Prefer foreground-only, which avoids Android foreground-service-type declarations entirely.** If Design D ever ships, budget for the Play Console FGS declaration + demo video, and note that Play rejects apps declaring FGS types they don't genuinely use.
- **Keep acoustic data out of HealthKit / Health Connect.** The handoff deliberately keeps App Store health-data review painless; don't spend that.
- **Contributed-audio opt-in needs its own privacy-policy section** and a data-deletion path that actually covers it.

---

## 9. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| False positives in public | **High** — this is the review-killer | Precision-biased threshold; confirm/dismiss on every detection; extensive hard-negative training |
| Raspberry cheating in duels | **High** for competitive integrity | Don't fight it. Honour-system framing; separate counter; social anti-cheat |
| Heard events polluting health data / world stats | **High** — undermines the whole positioning | Hard architectural split on `source`; heard events excluded from `report-stats` |
| Microphone PR / trust | **High** | On-device only; opt-in default-off contribution; loud, specific disclosure |
| Battery complaints | Medium | Session-based, not always-on; cascade so the model rarely runs |
| Training data never reaches quality | Medium | Ship Design A first — it's useful even at mediocre accuracy and it generates the data |
| **Novelty cliff** | **Medium-High, strategic** | See §11 |

---

## 10. Effort estimate — approved scope (A + B + C)

The scope now includes the entire duels subsystem, which is greenfield: the codebase has a `DuelsScreen` "coming soon" teaser and **nothing else** — no tables, no RLS, no edge functions, no domain model.

**Track 1 — Audio** *(no dependency on duels)*

| Step | Scope | Estimate |
|---|---|---|
| Spike | YAMNet zero-shot on-device; precision/recall on 100 real-room clips | 1 wk |
| Data + training | Freesound CC0 harvest, own recordings, augmentation, head training, eval harness | 2–3 wks |
| **A — tag assist** | Cascade, isolate, gateways, permission flow, Drift + Supabase `source` migration | 2 wks |
| **B — Listen mode** | Session UI, live Gust, confirm/dismiss, l10n, diagnostics | 2–3 wks |
| | | **7–9 wks** |

**Track 2 — Duels** *(no dependency on audio)*

| Step | Scope | Estimate |
|---|---|---|
| Backend | `duels` / `duel_members` / `duel_results`, RLS, Realtime authorization, 3–4 edge functions | 2–3 wks |
| Async duels | Create/join/list/detail UI, join codes, scoring, results share card | 2–3 wks |
| Safety | Curated-name generator (§13.3), report flow, anti-cheat heuristics | 1 wk |
| | | **5–7 wks** |

**Join — Live duels** *(needs both tracks)*

| Step | Scope | Estimate |
|---|---|---|
| **C — live duels** | Realtime session sync, throttled broadcast, live scoreboard, countdown, winner card | 3–4 wks |

**Total: 15–20 weeks of focused work**, or roughly **10–13 weeks wall-clock if the two tracks run in parallel.** That parallelism is the single biggest schedule lever available — the tracks share only the `PuffEvent.source` field, so they can be built independently and integrated late.

The **spike stays first and stays decisive.** If zero-shot YAMNet can't clear ~70 % precision on real-room recordings, the head has further to travel than Track 1 assumes, and the estimate moves. It's one week to find out.

---

## 11. Monetization

Handoff rules: Pro sells *depth, memory and social play* — never removal of annoyances. Never block the tap. No ads.

**Free**
- Tag assist (§7.1) — it improves the core loop, and the core loop is never paywalled
- Listen mode, **time-boxed**: one 5-minute session a day. Enough to delight and to screenshot. Live detection is the new "wow" moment — if free users can't see it, it can't drive acquisition.

- **Joining one duel** — async or live. The handoff is explicit that free joins one duel; that's the install prompt and it must stay free, because *the invited person is the acquisition*.

**Pro**
- Unlimited and long Listen sessions
- **Unlimited duels, and the right to create them** — async *and* live, shipping together
- **Sound signature stats** — pitch, duration and loudness distributions over time. This is *genuinely new analytical depth that only live mode can produce*, which is precisely the "Pro sells depth" rule rather than a gate on an annoyance.
- Wrapped audio superlatives — "your loudest toot of 2026: March 14, 11:42 pm". Strong share-card fuel.

**Why shipping both duel modes together works commercially.** They sell to different halves of the audience with one build: async week-long duels are the *retention* mechanic (a reason to open the app tomorrow), live duels are the *acquisition* mechanic (a party trick that needs a second phone in the room). Landing them in the same release means the Pro pitch is "duels" — one clear thing — rather than two half-features arriving months apart. It also lets the paywall trigger fire twice from one feature: *"you're already in a duel — go unlimited"* and *"want to start one? that's Pro."*

**New IAP surface**
- **Reaction packs** — the sound and animation Gust plays when a live detection fires. Slots directly into the already-planned cosmetics store (§Phase 2), pure margin, and giftable — the handoff already identifies gifting as a growth loop.

**Do not:** paywall the detector itself, charge per detection, or add a rewarded ad here.

**Expected effect:** this doesn't justify a price increase — it justifies a **conversion-rate** increase. It creates a natural paywall moment ("session's up — go unlimited") at a peak of engagement, and it's a party trick people demonstrate to friends, which historically drives **lifetime-unlock** purchases in joke-adjacent apps.

---

## 12. Standing cautions

The scope is approved; these remain true and should shape the designs rather than reopen the decision.

**1 · The novelty cliff still applies.** The handoff is explicit: *"the joke fades in weeks; retention lives in streaks, duels, and the food detective."* This programme delivers **duels** — one of the three named retention mechanics — which is a genuine point in its favour and materially strengthens the case versus building Listen mode alone. But the **trigger food detective and doctor report remain unbuilt**, and those are what the handoff identifies as the long-term moat with the GI cohort. This programme should be understood as spending the acquisition/retention budget, not the moat budget. Plan the food detective as the next thing after it, not the thing after that.

**2 · Never claim verification we can't deliver.** A mouth raspberry beats the classifier and always will (§2.2). Shipping both duel modes together actually *resolves* this neatly, and the split should be explicit in the product:

| | Async duels | Live duels |
|---|---|---|
| Source of truth | Tapped events | Heard events |
| Framing | The real competition | Party mode |
| Anti-cheat | Server-side plausibility limits | **Social** — you're in the same room |

Let async duels carry the competitive weight and live duels carry the fun. Then acoustic cheating stops being a threat model and becomes a joke we're in on.

**3 · Precision over recall, permanently.** A missed detection is a shrug. A phantom one in a quiet room is a screenshot and a 1-star review.

**4 · Heard events never touch health data.** Hard architectural line on `source` (§5.4). Not a preference — it's what keeps the world-stats number meaningful and the store review painless.

---

## 13. Final research — verified decisions before implementation

### 13.1 The model artefact

YAMNet's TFLite signature, confirmed:

| | Shape | Notes |
|---|---|---|
| **Input** | `[1, 15600]` float32 | 0.975 s @ 16 kHz mono, raw waveform — no client-side mel-spectrogram code needed, it's inside the graph |
| Output 0 | `[1, 521]` | Class scores. Index **55** = the class we want |
| **Output 1** | `[1, 1024]` | **Embedding — this is what our head consumes** |
| Output 2 | `[96, 64]` | Log-mel spectrogram. Useful for debugging and for the acoustic tag features (§7.1) |

Two consequences worth designing around:

- The head reads **output 1, not output 0.** Output 0 is only for the zero-shot spike and as a sanity signal. Once the head exists, index 55 becomes at most one input feature among 1024.
- Output 2 gives us the spectrogram for free, so F0 / harmonicity / duration features for **Squeaky vs. Thunder vs. Windy** tag assist come at zero extra inference cost.

### 13.2 Runtime — two corrections to the original plan

**Use [`flutter_litert`](https://pub.dev/packages/flutter_litert) (v3.6.0, Apache-2.0), not `tflite_flutter`.**

`tflite_flutter` is at 0.12.1 and effectively stalled. Google renamed TensorFlow Lite to **LiteRT**, and stated that all future feature and performance work is exclusive to LiteRT. `flutter_litert` began as a fork of `tflite_flutter`, keeps the `Interpreter` API **source-compatible** (so this is a low-risk choice, not a bet), and adds three things we want:

- **Bundled native libraries on every platform** — no manual `.so`/`.dylib`/`.dll` wrangling, which is exactly the tax `tflite_flutter` charges
- `CompiledModel` (LiteRT Next) for GPU/NPU delegation — we won't need it at 69 M multiplies, but it's free headroom
- Actively published, verified publisher, Apache-2.0 (so it stacks cleanly with YAMNet's own licence)

Keep `IsolateInterpreter`-style isolate inference either way.

**⚠️ Disable every speech DSP feature on the microphone.** `record` exposes echo cancellation, noise suppression and auto gain control. All three must be **off**:

| Feature | Why it breaks us |
|---|---|
| **Auto gain control** | Normalises loudness — destroying the single most useful feature for separating *Thunder* from *Squeaky*, and flattening the dynamics the head learns from |
| **Noise suppression** | Tuned to preserve speech and attenuate everything else. A toot is, to that algorithm, textbook noise — **it will actively suppress the thing we're trying to detect** |
| **Echo cancellation** | Adaptive filtering that alters the spectrum unpredictably between devices, destroying train/test consistency |

This is a silent killer: everything works in testing on one device, then accuracy varies inexplicably across handsets because each OEM's DSP differs. **Also record the training corpus with the same settings we run inference with** — train/serve skew in the audio front-end is the classic way these projects fail.

**Platform note:** the repo is **Android-only** today (no `ios/` directory; `pubspec.yaml` sets `ios: false` for both icons and splash). That simplifies v1 to `RECORD_AUDIO` in the manifest. Check `minSdk` — `record` needs 23, LiteRT wants **26**; bump to 26 if it isn't there. Design the gateways so iOS is a later drop-in (`NSMicrophoneUsageDescription` + nothing else), not a rewrite.

### 13.3 Duels — architecture, and a way to delete the stated blocker

**Realtime is the right transport, and it has hard numbers:**

| | Free | Pro | Pro (no spend cap) |
|---|---|---|---|
| Concurrent connections | 200 | **500** | 10,000 |
| Messages/second | 100 | **500** | 2,500 |
| Channel joins/second | 100 | 500 | 2,500 |
| Max broadcast size | 256 KB | 3 MB | 3 MB |

Presence calls are capped at **5 per client per 30 s** on every tier.

**Design consequence — do not broadcast per detection.** On Pro, 500 concurrent connections is only **250 simultaneous live duels**, and 2 clients × 1 msg/s would sit exactly on the 500 msg/s ceiling at that occupancy. So:

- **Throttle broadcasts to one coalesced count update every ~2 s per client**, not one per detection
- Render the opponent's score optimistically between updates so it still *feels* live
- Treat "live duel" as a **short, bounded round** (3 minutes) — this is a product virtue *and* a capacity strategy
- Watch the connection ceiling as an actual launch metric; the escape hatches are the no-spend-cap Pro tier, or moving just the Realtime layer elsewhere

**Security — use Realtime Authorization, not public channels.** Private channels (`config: { private: true }`) authorize via RLS policies on `realtime.messages`, using the `realtime.topic()` helper joined against `duel_members`. This requires disabling "Allow public access" in Realtime settings. It fits the repo's existing conviction that **RLS is the whole security model**, and it means a duel channel can't be joined by anyone who isn't a member — enforced in Postgres, not in the client.

Note this is a deliberate, documented exception to the repo rule that *the client only ever calls edge functions*: Realtime joins the client↔Supabase surface alongside Auth. Authorization still lives in RLS, and everything else about duels (create, join, submit results, settle) goes through edge functions as usual.

**Deleting the profanity blocker.** TODO.md lists *"profanity filter and report flow for duel/league names"* as a hard blocker before any social ships. The best Dart option is [`safe_text`](https://pub.dev/packages/safe_text) (maintained, leet-speak normalisation) — but **client-side filtering is not moderation**; it must be enforced in the edge function that creates the duel, since a crafted client can skip any client-side check.

**Better: don't ship free-text duel names in v1 at all.** Generate them from a curated word list — *"Breezy Badgers vs. Silent Storm"*, with a reroll button. This:

- **Eliminates the blocker entirely** rather than mitigating it — no user-generated text, no moderation surface, no report queue on day one
- Is *more* on-brand than free text, and reliably funnier
- Removes a whole class of store-review risk from a product whose humour already has to stay PG (handoff §9)
- Keeps `safe_text` + a report flow in reserve for when custom names ship as a Pro cosmetic

**Anti-cheat for async duels** (where it actually matters — see §12): server-side plausibility limits in the settle function, per the handoff's *"physical upper bound on plausible taps per hour"*. Heard events are excluded from async duel scoring entirely.

### 13.4 Build plan

Two independent tracks. The only shared surface is `PuffEvent.source`, so **agree that field first**, then the tracks don't need to talk again until the join.

```
Week 0    ├─ SPIKE: zero-shot YAMNet, 100 real-room clips  ◄── go/no-go
          │
          ├── TRACK 1 · AUDIO ─────────────┐  ├── TRACK 2 · DUELS ──────────┐
Weeks 1-3 │  data harvest + head training  │  │  backend: tables, RLS,      │
          │  (Freesound CC0 via API        │  │  Realtime authz, edge fns   │
          │   license filter)              │  │                             │
Weeks 3-5 │  A · tag assist                │  │  async duels UI + join codes│
Weeks 5-8 │  B · Listen mode               │  │  curated names, anti-cheat, │
          │                                │  │  report flow                │
          └────────────────┬───────────────┘  └──────────┬──────────────────┘
                           └──────────► JOIN ◄───────────┘
Weeks 8-12                     C · live duels
                        (Realtime session, throttled
                         broadcast, live scoreboard)
```

**Shared prerequisite, do it once, first:** the `source` field — `PuffEvent`, Drift migration, `supabase/migrations/0006_event_source.sql`, and the `StatsService` filtering rules. Both tracks depend on it and nothing else.

### 13.5 Open questions for the design phase

1. **Detection confirm UX** — modal confirm per detection, or a silent log with undo? Confirm gives labelled training data (§6.4); undo is smoother. Possibly: confirm during the first sessions, then decay to undo once the user's precision is established.
2. **Duel round length** — 3 minutes is the capacity-friendly assumption. Needs a play-test.
3. **Free Listen-mode budget** — one 5-minute session/day is a starting guess, not a researched number. Instrument it and tune.
4. **Contributed-audio opt-in placement** — during onboarding (higher opt-in, feels like a bigger ask) or after a few sessions (lower opt-in, better-informed consent)? Leaning later.
5. **Join codes vs. deep links** — recommend 6-character join codes for v1: no deep-link infrastructure, works over any chat app, trivially shareable as text.

---

## Sources

- [YAMNet — tensorflow/models](https://github.com/tensorflow/models/tree/master/research/audioset/yamnet) · [class map (Fart = 55)](https://github.com/tensorflow/models/blob/master/research/audioset/yamnet/yamnet_class_map.csv) · [Apache 2.0 LICENSE](https://raw.githubusercontent.com/tensorflow/models/master/LICENSE)
- [AudioSet — Fart class statistics](https://research.google.com/audioset/dataset/fart.html) · [AudioSet dataset licensing](https://git-disl.github.io/GTDLBench/datasets/audioset_dataset/)
- [PANNs pretrained models (Zenodo, CC-BY)](https://zenodo.org/records/3576403) · [audioset_tagging_cnn](https://github.com/qiuqiangkong/audioset_tagging_cnn)
- [FSD50K release notes & per-clip licensing](http://www.eduardofonseca.net/datasets/2020/10/02/FSD50K-release.html) · [FSD50K paper](https://ar5iv.arxiv.org/html/2010.00475)
- [Apple Sound Analysis framework](https://developer.apple.com/documentation/soundanalysis/) · [SNClassifySoundRequest](https://developer.apple.com/documentation/soundanalysis/snclassifysoundrequest)
- [MediaPipe Audio Classifier guide](https://ai.google.dev/edge/mediapipe/solutions/audio/audio_classifier) · [Sound classification with YAMNet (TF Hub)](https://www.tensorflow.org/hub/tutorials/yamnet)
- [`record` package (PCM16 streaming)](https://pub.dev/packages/record) · [`flutter_litert`](https://pub.dev/packages/flutter_litert) · [`tflite_flutter`](https://pub.dev/packages/tflite_flutter) · [`safe_text`](https://pub.dev/packages/safe_text)
- [TensorFlow Lite is now LiteRT](https://developers.googleblog.com/en/tensorflow-lite-is-now-litert/) · [LiteRT migration guide](https://ai.google.dev/edge/litert/migration)
- [Supabase Realtime limits](https://supabase.com/docs/guides/realtime/limits) · [Supabase Realtime Authorization](https://supabase.com/docs/guides/realtime/authorization)
- [Converting YAMNet for TFLite inference](https://medium.com/@antonyharfield/converting-the-yamnet-audio-detection-model-for-tensorflow-lite-inference-43d049bd357c) · [Transfer learning with YAMNet](https://www.tensorflow.org/tutorials/audio/transfer_learning_audio)
- [Freesound FAQ & licensing](https://freesound.org/help/faq/) · [Freesound licence filtering](https://freesound.org/forum/bug-reports-errors-and-feature-requests/43161/)
- [Android foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types) · [Play Console FGS requirements](https://support.google.com/googleplay/android-developer/answer/13392821?hl=en)
- [Benchmarking ML for bowel sound classification (2026)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12758754/) · [Automated bowel sound analysis with CNN using a smartphone](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9824196/)
