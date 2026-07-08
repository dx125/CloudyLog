// The daily anonymous stats report — every tier's stake in world stats.
//
//   POST { days: [{ day: "YYYY-MM-DD", count: 1..1000 }] }   (≤ 31 entries)
//     → upsert into user_daily_stats for the calling user. Free and Pro
//       alike; RLS keeps rows own-only. `day` is the client's local date
//       (see 0005_stat_reports.sql).
//
// The client sends this once per local day; re-sends of the same window are
// idempotent upserts, so a partial "today" is corrected by tomorrow's report.

import { errorStatus, json, userClient } from "../_shared/edge.ts";

const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const supabase = userClient(req);
  const body = await req.json().catch(() => null);
  const days = body?.days;
  if (!Array.isArray(days) || days.length > 31) {
    return json({ error: "'days' must be an array of at most 31 entries" }, 400);
  }
  for (const d of days) {
    if (
      typeof d?.day !== "string" || !DAY_RE.test(d.day) ||
      !Number.isInteger(d?.count) || d.count < 1 || d.count > 1000
    ) {
      return json(
        { error: "each entry needs day 'YYYY-MM-DD' and count 1..1000" },
        400,
      );
    }
  }
  if (days.length === 0) return json({ reported: 0 });

  // Explicit user_id: the upsert resolves conflicts on the full primary key
  // (user_id, day), so the row must carry it. RLS still checks it's the
  // caller's own id.
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData?.user) {
    return json({ error: "not authenticated" }, 401);
  }

  const rows = days.map((d) => ({
    user_id: userData.user.id,
    day: d.day,
    toot_count: d.count,
    reported_at: new Date().toISOString(),
  }));
  const { error } = await supabase.from("user_daily_stats").upsert(rows);
  if (error) return json({ error: error.message }, errorStatus(error.code));
  return json({ reported: rows.length });
});
