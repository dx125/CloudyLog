-- =============================================================================
-- Puff — hardening for the duel helper functions.
--
-- Two findings from `supabase db advisors --type security` against 0008/0009,
-- both of which are the same mistake: granting EXECUTE without first revoking
-- Postgres's default grant to PUBLIC.
--
--   1. `is_duel_member` is SECURITY DEFINER and was executable by `anon`.
--      Harmless in practice — it reads auth.uid(), which is null for anon, so
--      it always returned false — but a definer function reachable by an
--      unauthenticated role is exactly the shape of a privilege bug, and the
--      convention set in 0002 is to revoke from public first.
--
--   2. `duel_id_from_topic` had a mutable search_path. It's not SECURITY
--      DEFINER so the risk is small, but it *is* called from inside the
--      realtime.messages RLS policies, and a function that decides channel
--      access shouldn't resolve its operators through a caller-controlled
--      path.
--
-- Neither changes behaviour; both close the gap between 0008/0009 and the
-- pattern 0002 and 0004 already established.
-- =============================================================================

-- Fixed search_path. Empty rather than `public`: this function touches no
-- tables at all — only string operators and a cast, which live in pg_catalog
-- and are always resolvable.
create or replace function duel_id_from_topic(topic text)
returns uuid
language plpgsql
immutable
set search_path = ''
as $$
declare
  raw text;
begin
  if topic is null or left(topic, 5) <> 'duel:' then
    return null;
  end if;
  raw := substring(topic from 6);
  return raw::uuid;
exception
  when others then
    return null;
end;
$$;

revoke execute on function is_duel_member(uuid) from public;
revoke execute on function duel_id_from_topic(text) from public;

grant execute on function is_duel_member(uuid) to authenticated;
grant execute on function duel_id_from_topic(text) to authenticated;
