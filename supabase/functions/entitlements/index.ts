// Pro entitlement state and the mock dev billing actions.
//
//   GET                        → the caller's entitlement, or null.
//   POST { action: "purchase"} → activate_mock_pro() (30 days per activation)
//   POST { action: "cancel" }  → cancel_mock_pro() (Pro persists until expiry)
//
// When RevenueCat lands its webhook writes `entitlements` instead and the
// POST actions go away; GET stays as the client's read path.

import { json, userClient } from "../_shared/edge.ts";

type EntitlementRow = {
  status: string;
  expires_at: string;
  provider: string;
};

function trim(row: EntitlementRow | null) {
  return row === null ? null : {
    status: row.status,
    expires_at: row.expires_at,
    provider: row.provider,
  };
}

Deno.serve(async (req) => {
  const supabase = userClient(req);

  if (req.method === "GET") {
    const { data, error } = await supabase
      .from("entitlements")
      .select("status, expires_at, provider")
      .maybeSingle();
    if (error) return json({ error: error.message }, 500);
    return json({ entitlement: trim(data) });
  }

  if (req.method === "POST") {
    const body = await req.json().catch(() => null);
    const rpc = body?.action === "purchase"
      ? "activate_mock_pro"
      : body?.action === "cancel"
      ? "cancel_mock_pro"
      : null;
    if (rpc === null) {
      return json({ error: "'action' must be 'purchase' or 'cancel'" }, 400);
    }
    const { data, error } = await supabase.rpc(rpc);
    if (error) return json({ error: error.message }, 400);
    return json({ entitlement: trim(data) });
  }

  return json({ error: "method not allowed" }, 405);
});
