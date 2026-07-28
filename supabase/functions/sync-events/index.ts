// Cloud sync for the on-device event log (Pro; enforced by RLS on `events`).
//
//   POST { events: [{ id, type, occurred_at, tags, device_id, source }] }
//     → idempotent upsert by client-generated UUIDv7; last-write-wins is safe
//       because events are immutable except for the quick-tag window.
//   GET
//     → every event the user owns, for restore-onto-a-new-device.
//
// `source` is 'tap' | 'heard' (migration 0007). Older clients omit it and the
// column default fills in 'tap', which is what those events were.

import { errorStatus, json, userClient } from "../_shared/edge.ts";

Deno.serve(async (req) => {
  const supabase = userClient(req);

  if (req.method === "GET") {
    const { data, error } = await supabase
      .from("events")
      .select("id, type, occurred_at, tags, device_id, source")
      .order("occurred_at", { ascending: true });
    if (error) return json({ error: error.message }, errorStatus(error.code));
    return json({ events: data });
  }

  if (req.method === "POST") {
    const body = await req.json().catch(() => null);
    const events = body?.events;
    if (!Array.isArray(events)) {
      return json({ error: "'events' must be an array" }, 400);
    }
    if (events.length === 0) return json({ pushed: 0 });

    const rows = events.map((e) => ({
      id: e.id,
      type: e.type,
      occurred_at: e.occurred_at,
      tags: e.tags ?? [],
      device_id: e.device_id ?? "",
      source: e.source === "heard" ? "heard" : "tap",
    }));
    const { error } = await supabase.from("events").upsert(rows);
    if (error) return json({ error: error.message }, errorStatus(error.code));
    return json({ pushed: rows.length });
  }

  return json({ error: "method not allowed" }, 405);
});
