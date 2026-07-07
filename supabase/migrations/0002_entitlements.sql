-- =============================================================================
-- Puff — Pro entitlements.
--
-- One row per user mirroring their subscription state. Users can only READ
-- their own entitlement; nothing client-side can write the table directly.
-- Writes happen through:
--   * activate_mock_pro() / cancel_mock_pro() — development billing (security
--     definer RPCs). When RevenueCat lands, its webhook (service_role) writes
--     here instead and these two functions are dropped; the client's
--     PurchaseGateway seam is the only code that changes on the app side.
--
-- Entitlement rule (same everywhere): Pro until expires_at, even if canceled.
-- =============================================================================

create table if not exists entitlements (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  product    text not null default 'pro',
  status     text not null check (status in ('active', 'canceled')),
  provider   text not null default 'mock' check (provider in ('mock', 'revenuecat')),
  started_at timestamptz not null default now(),
  expires_at timestamptz not null,
  updated_at timestamptz not null default now()
);

alter table entitlements enable row level security;

create policy "entitlements: read own"
  on entitlements for select
  to authenticated
  using (user_id = (select auth.uid()));

-- No insert/update/delete policies: direct writes are denied for everyone
-- except definer functions and service_role.

-- Single source of truth for "is this user Pro right now" — used by RLS
-- policies on Pro-only tables (events sync).
create or replace function has_active_pro(uid uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from entitlements
    where user_id = uid and expires_at > now()
  );
$$;

-- ---------------------------------------------------------------------------
-- Development billing (mock provider). 30 days per activation; re-activation
-- extends from now and keeps the original started_at.
-- ---------------------------------------------------------------------------

create or replace function activate_mock_pro()
returns entitlements
language plpgsql
security definer
set search_path = public
as $$
declare
  result entitlements;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  insert into entitlements (user_id, status, provider, started_at, expires_at, updated_at)
  values (auth.uid(), 'active', 'mock', now(), now() + interval '30 days', now())
  on conflict (user_id) do update
    set status = 'active',
        provider = 'mock',
        expires_at = now() + interval '30 days',
        updated_at = now()
  returning * into result;
  return result;
end;
$$;

create or replace function cancel_mock_pro()
returns entitlements
language plpgsql
security definer
set search_path = public
as $$
declare
  result entitlements;
begin
  update entitlements
  set status = 'canceled', updated_at = now()
  where user_id = auth.uid() and expires_at > now()
  returning * into result;
  if result is null then
    raise exception 'no active subscription';
  end if;
  return result;
end;
$$;

-- Privacy is a launch feature: deletion is one tap and total. Removing the
-- auth user cascades through profiles, entitlements and events.
create or replace function delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke execute on all functions in schema public from public;
grant execute on function has_active_pro(uuid) to authenticated;
grant execute on function activate_mock_pro() to authenticated;
grant execute on function cancel_mock_pro() to authenticated;
grant execute on function delete_my_account() to authenticated;
