// Shared helpers for Puff edge functions.
//
// The functions API is the only way the app talks to the backend — the client
// never queries tables or RPCs directly. Every function runs with the
// *caller's* JWT: `userClient` forwards the Authorization header, so
// auth.uid() resolves inside SQL and every RLS policy and definer function
// keeps applying. Functions add no privileges — no service_role anywhere.

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

export function userClient(req: Request): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: {
        headers: { Authorization: req.headers.get("Authorization") ?? "" },
      },
      auth: { persistSession: false, autoRefreshToken: false },
    },
  );
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// 42501 = insufficient_privilege: an RLS policy said no (e.g. a free user
// pushing events). Everything else is a plain 500.
export function errorStatus(code: string | undefined): number {
  return code === "42501" ? 403 : 500;
}
