// Duels — async (tap-scored weeks) and live (heard-scored 3-minute rounds).
//
//   GET                          → my duels, with members and scores
//   GET ?code=XXXXXX             → preview one duel before joining
//   POST { action: "create" }    → create (RLS Pro-gates it), seat the creator
//   POST { action: "join" }      → join by code
//   POST { action: "score" }     → submit my score (validated, see below)
//   POST { action: "leave" }     → drop out
//
// Runs on the caller's JWT like every other function, so RLS decides everything
// about visibility and the Pro gate on creation. No service_role.
//
// Two rules this function enforces that RLS can't express:
//  * plausibility — a physical ceiling on taps per hour (handoff §8), so a
//    tampered client can't submit a five-figure week;
//  * monotonicity — a score may never go down, which kills replay/rollback
//    games without needing to store history.
//
// Live duels are deliberately *not* hardened beyond this. A mouth raspberry
// defeats any classifier we can ship, so live rounds are honour-system party
// mode and the anti-cheat is social. Async duels carry the competitive weight.

import { errorStatus, json, userClient } from "../_shared/edge.ts";

// Unambiguous alphabet: no I/O/0/1, because these get read aloud and retyped.
const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 6;

// Curated-name vocabulary sizes. The client renders the words; the server only
// ever sees indices, so a slur has no column to live in. Keep in sync with
// lib/domain/duel.dart.
const ADJECTIVE_COUNT = 24;
const NOUN_COUNT = 24;
const HANDLE_COUNT = 24;

// Plausibility ceilings. These exist to stop a tampered client claiming five
// figures — not to police enthusiasm — so they are deliberately loose.
//
// The cap is a burst allowance *plus* a sustained rate. The burst term matters:
// a rate-only cap makes a freshly created duel allow ~1 tap, because barely any
// time has elapsed, and a real user tapping a dozen times in the first minute
// would be scored 1. (Exactly that happened on the first live test.) Real
// tapping is bursty; only the long-run average is bounded by physiology.
const MAX_TAPS_PER_HOUR = 40;
const MAX_HEARD_PER_HOUR = 120;
const TAP_BURST_ALLOWANCE = 60;
const HEARD_BURST_ALLOWANCE = 200;

function newCode(): string {
  const bytes = new Uint8Array(CODE_LENGTH);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => CODE_ALPHABET[b % CODE_ALPHABET.length])
    .join("");
}

function randomIndex(count: number): number {
  return Math.floor(Math.random() * count);
}

function hoursBetween(from: string, to: string): number {
  const ms = new Date(to).getTime() - new Date(from).getTime();
  return Math.max(ms / 3_600_000, 1 / 60);
}

Deno.serve(async (req) => {
  const supabase = userClient(req);
  const url = new URL(req.url);

  // ---------------------------------------------------------------- GET ----
  if (req.method === "GET") {
    const code = url.searchParams.get("code");

    if (code) {
      // Preview before joining. Goes through the definer lookup (migration
      // 0011), not the table: the caller isn't a member yet, so the table's
      // SELECT policy would hide the row and every join would report "no such
      // duel". The function returns only what an invitation already implies —
      // no member list, no scores.
      const { data, error } = await supabase
        .rpc("duel_by_code", { p_code: code })
        .maybeSingle();
      if (error) return json({ error: error.message }, errorStatus(error.code));
      return json({ duel: data });
    }

    const { data, error } = await supabase
      .from("duels")
      .select(
        "id, code, kind, name_adj, name_noun, created_by, starts_at, ends_at, status, " +
          "duel_members(user_id, handle), duel_scores(user_id, tapped, heard, updated_at)",
      )
      .order("created_at", { ascending: false });
    if (error) return json({ error: error.message }, errorStatus(error.code));
    return json({ duels: data ?? [] });
  }

  if (req.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  const body = await req.json().catch(() => null);
  const action = body?.action;

  const { data: auth } = await supabase.auth.getUser();
  const userId = auth?.user?.id;
  if (!userId) return json({ error: "not signed in" }, 401);

  // ------------------------------------------------------------- create ----
  if (action === "create") {
    const kind = body?.kind === "live" ? "live" : "async";
    const startsAt = new Date();
    // A live round is minutes; an async duel is a week. The live window is
    // also a capacity strategy — see the Realtime budget in the design doc.
    const endsAt = new Date(
      startsAt.getTime() +
        (kind === "live" ? 3 * 60_000 : 7 * 24 * 3_600_000),
    );

    // Retry on the (vanishingly unlikely) code collision rather than failing
    // the user's tap.
    for (let attempt = 0; attempt < 5; attempt++) {
      const { data, error } = await supabase
        .from("duels")
        .insert({
          code: newCode(),
          kind,
          name_adj: randomIndex(ADJECTIVE_COUNT),
          name_noun: randomIndex(NOUN_COUNT),
          starts_at: startsAt.toISOString(),
          ends_at: endsAt.toISOString(),
          status: kind === "live" ? "running" : "open",
        })
        .select("id, code, kind, name_adj, name_noun, starts_at, ends_at, status")
        .single();

      if (error) {
        if (error.code === "23505") continue; // duplicate code, try again
        return json({ error: error.message }, errorStatus(error.code));
      }

      // Seat the creator. Their own INSERT policy covers this.
      const { error: joinError } = await supabase
        .from("duel_members")
        .insert({ duel_id: data.id, handle: randomIndex(HANDLE_COUNT) });
      if (joinError) {
        return json({ error: joinError.message }, errorStatus(joinError.code));
      }
      return json({ duel: data });
    }
    return json({ error: "could not allocate a code" }, 503);
  }

  // --------------------------------------------------------------- join ----
  if (action === "join") {
    const code = String(body?.code ?? "").toUpperCase();
    if (!code) return json({ error: "'code' is required" }, 400);

    // Definer lookup, for the same reason as the preview above: membership
    // can't be a precondition for the query that decides whether to grant it.
    const { data: duel, error } = await supabase
      .rpc("duel_by_code", { p_code: code })
      .maybeSingle();
    if (error) return json({ error: error.message }, errorStatus(error.code));
    if (!duel) return json({ error: "no such duel" }, 404);
    if (new Date(duel.ends_at) < new Date()) {
      return json({ error: "that duel is over" }, 409);
    }

    // Free tier joins one duel; Pro is unlimited. Checked here rather than in
    // RLS because it's a count across rows, not a property of one.
    const { data: entitlement } = await supabase
      .from("entitlements")
      .select("status, expires_at")
      .maybeSingle();
    const isPro = entitlement !== null &&
      new Date(entitlement.expires_at) > new Date();

    if (!isPro) {
      const { count } = await supabase
        .from("duel_members")
        .select("duel_id", { count: "exact", head: true })
        .eq("user_id", userId);
      if ((count ?? 0) >= 1) {
        return json({ error: "free tier is one duel at a time", pro: true }, 402);
      }
    }

    const { error: joinError } = await supabase
      .from("duel_members")
      .insert({ duel_id: duel.id, handle: randomIndex(HANDLE_COUNT) });
    // Already a member: idempotent, not an error.
    if (joinError && joinError.code !== "23505") {
      return json({ error: joinError.message }, errorStatus(joinError.code));
    }
    return json({ joined: duel.id });
  }

  // -------------------------------------------------------------- score ----
  if (action === "score") {
    const duelId = body?.duel_id;
    if (!duelId) return json({ error: "'duel_id' is required" }, 400);

    const { data: duel, error } = await supabase
      .from("duels")
      .select("id, kind, starts_at, ends_at")
      .eq("id", duelId)
      .maybeSingle();
    if (error) return json({ error: error.message }, errorStatus(error.code));
    if (!duel) return json({ error: "no such duel" }, 404);

    // Clamp to what's physically plausible over the duel's own window.
    const now = new Date().toISOString();
    const elapsed = hoursBetween(
      duel.starts_at,
      now < duel.ends_at ? now : duel.ends_at,
    );
    const tapped = Math.min(
      Math.max(Number(body?.tapped ?? 0) | 0, 0),
      TAP_BURST_ALLOWANCE + Math.ceil(elapsed * MAX_TAPS_PER_HOUR),
    );
    const heard = Math.min(
      Math.max(Number(body?.heard ?? 0) | 0, 0),
      HEARD_BURST_ALLOWANCE + Math.ceil(elapsed * MAX_HEARD_PER_HOUR),
    );

    // Monotonic: a submission may raise a score, never lower it.
    const { data: existing } = await supabase
      .from("duel_scores")
      .select("tapped, heard")
      .eq("duel_id", duelId)
      .eq("user_id", userId)
      .maybeSingle();

    const row = {
      duel_id: duelId,
      user_id: userId,
      tapped: Math.max(tapped, existing?.tapped ?? 0),
      heard: Math.max(heard, existing?.heard ?? 0),
      updated_at: now,
    };

    const { error: writeError } = await supabase
      .from("duel_scores")
      .upsert(row, { onConflict: "duel_id,user_id" });
    if (writeError) {
      return json({ error: writeError.message }, errorStatus(writeError.code));
    }
    return json({ score: { tapped: row.tapped, heard: row.heard } });
  }

  // -------------------------------------------------------------- leave ----
  if (action === "leave") {
    const duelId = body?.duel_id;
    if (!duelId) return json({ error: "'duel_id' is required" }, 400);
    const { error } = await supabase
      .from("duel_members")
      .delete()
      .eq("duel_id", duelId)
      .eq("user_id", userId);
    if (error) return json({ error: error.message }, errorStatus(error.code));
    return json({ left: duelId });
  }

  return json(
    { error: "'action' must be create, join, score or leave" },
    400,
  );
});
