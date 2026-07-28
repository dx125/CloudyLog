-- =============================================================================
-- Puff — Realtime authorization for live duel channels.
--
-- Live duels need both phones to see each other's score as it moves. That's the
-- one thing an edge function can't do, so Realtime joins Auth as a documented
-- exception to "the client only ever calls edge functions" (CLAUDE.md).
--
-- The exception is narrow, and authorization does not move with it: private
-- channels authorize through RLS on `realtime.messages`, so membership is still
-- decided in Postgres by the same is_duel_member() predicate as everything else.
-- Broadcast carries liveness only — the authoritative final score goes through
-- the `duels` edge function, never a broadcast a client could forge.
--
-- Topic convention: `duel:<uuid>`. The policies below strip the prefix and
-- check membership on the remainder.
--
-- DEPLOYMENT STEP (not expressible in SQL): turn **off** "Allow public access"
-- in the project's Realtime settings. Without that, channels stay public and
-- these policies are never consulted. Recorded in supabase/README.md.
-- =============================================================================

-- Extracts the duel id from a `duel:<uuid>` topic, or null for any other topic
-- (or a malformed one — a client can name a channel anything, so this must
-- never raise).
create or replace function duel_id_from_topic(topic text)
returns uuid
language plpgsql
immutable
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

grant execute on function duel_id_from_topic(text) to authenticated;

-- Read: receive broadcast and presence on a duel channel you belong to.
create policy "realtime: duel members receive"
  on realtime.messages for select
  to authenticated
  using (
    (select realtime.messages.extension) in ('broadcast', 'presence')
    and duel_id_from_topic((select realtime.topic())) is not null
    and is_duel_member(duel_id_from_topic((select realtime.topic())))
  );

-- Write: send broadcast and presence on a duel channel you belong to.
create policy "realtime: duel members send"
  on realtime.messages for insert
  to authenticated
  with check (
    (select realtime.messages.extension) in ('broadcast', 'presence')
    and duel_id_from_topic((select realtime.topic())) is not null
    and is_duel_member(duel_id_from_topic((select realtime.topic())))
  );
