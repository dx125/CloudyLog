// Latest anonymous global aggregate (world comparison / percentile).
//
//   GET → newest daily_global_stats row, or null before the first cron run.
//
// Aggregates only — raw population data never leaves the database.

import { json, userClient } from "../_shared/edge.ts";

Deno.serve(async (req) => {
  if (req.method !== "GET") return json({ error: "method not allowed" }, 405);

  const supabase = userClient(req);
  const { data, error } = await supabase
    .from("daily_global_stats")
    .select("day, total_users, distribution")
    .order("day", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) return json({ error: error.message }, 500);
  return json({ stats: data });
});
