-- ============================================================
-- Sunnad — Migration 9: Stage 6 Group Governance + Push Targeting
-- ============================================================

-- ------------------------------------------------------------
-- 1) Groups: lock state + rotation metadata
-- ------------------------------------------------------------
alter table public.groups
  add column if not exists join_locked boolean not null default false;

alter table public.groups
  add column if not exists code_rotated_at timestamptz;

create index if not exists groups_owner_lock_idx
  on public.groups (owner_id, join_locked);

-- ------------------------------------------------------------
-- 2) Owner-only group governance RPCs
-- ------------------------------------------------------------
create or replace function public.rename_group(p_group_id uuid, p_name text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_name text := trim(p_name);
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if v_name is null or v_name = '' then
    raise exception 'Group name is required';
  end if;

  update public.groups
  set name = v_name,
      updated_at = now()
  where id = p_group_id
    and owner_id = v_user_id;

  if not found then
    raise exception 'Forbidden';
  end if;
end;
$$;

revoke all on function public.rename_group(uuid, text) from public;
grant execute on function public.rename_group(uuid, text) to authenticated;

create or replace function public.set_group_join_lock(p_group_id uuid, p_locked boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  update public.groups
  set join_locked = p_locked,
      updated_at = now()
  where id = p_group_id
    and owner_id = v_user_id;

  if not found then
    raise exception 'Forbidden';
  end if;
end;
$$;

revoke all on function public.set_group_join_lock(uuid, boolean) from public;
grant execute on function public.set_group_join_lock(uuid, boolean) to authenticated;

create or replace function public.rotate_group_invite_code(p_group_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_code text;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1
    from public.groups g
    where g.id = p_group_id
      and g.owner_id = v_user_id
  ) then
    raise exception 'Forbidden';
  end if;

  loop
    v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    exit when not exists (
      select 1 from public.groups where code = v_code
    );
  end loop;

  update public.groups
  set code = v_code,
      code_rotated_at = now(),
      updated_at = now()
  where id = p_group_id
    and owner_id = v_user_id;

  return v_code;
end;
$$;

revoke all on function public.rotate_group_invite_code(uuid) from public;
grant execute on function public.rotate_group_invite_code(uuid) to authenticated;

-- ------------------------------------------------------------
-- 3) Lock-aware join RPC (normalized invite code retained)
-- ------------------------------------------------------------
create or replace function public.join_group_by_code(invite_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_group_id uuid;
  v_user_id uuid := auth.uid();
  v_code text := upper(trim(invite_code));
  v_join_locked boolean;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if v_code is null or v_code = '' then
    raise exception 'Invalid invite code';
  end if;

  select id, join_locked
    into v_group_id, v_join_locked
  from public.groups
  where upper(code) = v_code;

  if v_group_id is null then
    raise exception 'Invalid invite code';
  end if;

  if coalesce(v_join_locked, false) then
    raise exception 'Group join is locked';
  end if;

  insert into public.group_members (group_id, user_id, role)
  values (v_group_id, v_user_id, 'member')
  on conflict (group_id, user_id) do nothing;

  return v_group_id;
end;
$$;

revoke all on function public.join_group_by_code(text) from public;
grant execute on function public.join_group_by_code(text) to authenticated;

-- ------------------------------------------------------------
-- 4) Device token targeting for OneSignal-driven nudges
-- ------------------------------------------------------------
alter table public.device_tokens
  add column if not exists onesignal_subscription_id text;

create unique index if not exists device_tokens_onesignal_subscription_uidx
  on public.device_tokens (onesignal_subscription_id)
  where onesignal_subscription_id is not null;

create index if not exists device_tokens_user_platform_updated_idx
  on public.device_tokens (user_id, platform, updated_at desc);
