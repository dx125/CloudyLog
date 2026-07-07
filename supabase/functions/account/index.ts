// Account deletion — one tap and total (privacy is a launch feature).
//
//   DELETE → delete_my_account(): removes the auth user; profiles,
//            entitlements and events cascade away with it.

import { json, userClient } from "../_shared/edge.ts";

Deno.serve(async (req) => {
  if (req.method !== "DELETE") return json({ error: "method not allowed" }, 405);

  const supabase = userClient(req);
  const { error } = await supabase.rpc("delete_my_account");
  if (error) return json({ error: error.message }, 400);
  return json({ deleted: true });
});
