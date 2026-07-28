-- =============================================================================
-- Puff — fix two chicken-and-egg failures in the 0008 duel policies.
--
-- Both were found by exercising the deployed function against the real
-- database; neither is visible in unit tests, because both are about RLS
-- evaluating at a moment when the caller isn't a member *yet*.
--
-- (1) CREATE WAS IMPOSSIBLE.
--     `duels: members read` is `is_duel_member(id)`. PostgREST inserts with
--     RETURNING, and RETURNING requires the new row to pass the SELECT policy —
--     but the creator is seated in duel_members only *after* the insert. So
--     every create failed with "new row violates row-level security policy",
--     which reads like the Pro gate rejecting them. It wasn't; the Pro check
--     passed and the read-back failed.
--
--     Fix: creators can always read their own duels. Obviously correct on its
--     own terms — you need to see the duel you just made in order to share its
--     code — and it makes RETURNING work.
--
-- (2) JOINING WAS IMPOSSIBLE.
--     Looking a duel up by its code is the entire invite mechanism, and it
--     necessarily happens *before* membership exists. Under `is_duel_member`
--     the lookup returned no rows, so every join answered "no such duel".
--
--     Fix: a SECURITY DEFINER lookup that takes a code and returns only what an
--     invitation already implies — the name, kind and window. Deliberately not
--     the member list, not the scores, not the creator. Widening the table's
--     SELECT policy instead would have exposed every duel to every user, so the
--     narrow definer function is the safer shape.
--
--     Enumeration: codes are 6 characters from a 32-symbol alphabet (~1.07e9),
--     and a wrong guess reveals only that nothing matched.
-- =============================================================================

drop policy if exists "duels: members read" on duels;

create policy "duels: members and creator read"
  on duels for select
  to authenticated
  using (is_duel_member(id) or created_by = (select auth.uid()));

-- Preview/join lookup. Returns at most one row; null-safe on a bad code.
create or replace function duel_by_code(p_code text)
returns table (
  id uuid,
  code text,
  kind text,
  name_adj smallint,
  name_noun smallint,
  starts_at timestamptz,
  ends_at timestamptz,
  status text
)
language sql
security definer
stable
set search_path = public
as $$
  select d.id, d.code, d.kind, d.name_adj, d.name_noun,
         d.starts_at, d.ends_at, d.status
  from duels d
  where d.code = upper(p_code)
  limit 1;
$$;

revoke execute on function duel_by_code(text) from public;
grant execute on function duel_by_code(text) to authenticated;
