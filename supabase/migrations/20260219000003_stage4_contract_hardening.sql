-- ============================================================
-- Sunnad — Migration 3: Stage 4 Contract Hardening
-- ============================================================

-- ------------------------------------------------------------
-- 1) Group creation RPC: atomic group + owner membership
-- ------------------------------------------------------------
create or replace function public.create_group_with_owner(group_name text)
returns uuid
language plpgsql
security definer set search_path = ''
as $$
declare
  v_group_id uuid;
  v_user_id uuid := auth.uid();
  v_name text := trim(group_name);
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if v_name is null or v_name = '' then
    raise exception 'Group name is required';
  end if;

  insert into public.groups (owner_id, name)
  values (v_user_id, v_name)
  returning id into v_group_id;

  insert into public.group_members (group_id, user_id, role)
  values (v_group_id, v_user_id, 'owner')
  on conflict (group_id, user_id) do update
    set role = 'owner';

  return v_group_id;
end;
$$;

revoke all on function public.create_group_with_owner(text) from public;
grant execute on function public.create_group_with_owner(text) to authenticated;

-- ------------------------------------------------------------
-- 2) Harden join RPC: normalized invite codes + auth execute grant
-- ------------------------------------------------------------
create or replace function public.join_group_by_code(invite_code text)
returns uuid
language plpgsql
security definer set search_path = ''
as $$
declare
  v_group_id uuid;
  v_user_id uuid := auth.uid();
  v_code text := upper(trim(invite_code));
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if v_code is null or v_code = '' then
    raise exception 'Invalid invite code';
  end if;

  select id into v_group_id
  from public.groups
  where upper(code) = v_code;

  if v_group_id is null then
    raise exception 'Invalid invite code';
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
-- 3) Enforce schedule domain to supported values only
-- ------------------------------------------------------------
update public.habits
set schedule = 'daily'
where schedule not in ('daily', 'weekly');

alter table public.habits
  add constraint habits_schedule_supported
  check (schedule in ('daily', 'weekly'));

-- ------------------------------------------------------------
-- 4) Add ownership-enforcing composite FKs for sync safety
-- ------------------------------------------------------------
create unique index habits_user_id_id_uidx
  on public.habits (user_id, id);

update public.habit_completions hc
set user_id = h.user_id
from public.habits h
where hc.habit_id = h.id
  and hc.user_id <> h.user_id;

alter table public.habit_completions
  add constraint habit_completions_habit_owner_fk
  foreign key (user_id, habit_id)
  references public.habits (user_id, id)
  on delete cascade;

update public.group_shared_habits gsh
set user_id = h.user_id
from public.habits h
where gsh.habit_id = h.id
  and gsh.user_id <> h.user_id;

alter table public.group_shared_habits
  add constraint group_shared_habits_habit_owner_fk
  foreign key (user_id, habit_id)
  references public.habits (user_id, id)
  on delete cascade;

-- ------------------------------------------------------------
-- 5) Add sync-friendly updated_at columns where missing
-- ------------------------------------------------------------
alter table public.group_members
  add column updated_at timestamptz not null default now();

create trigger set_group_members_updated_at
  before update on public.group_members
  for each row execute function public.set_updated_at();

alter table public.saved_quotes
  add column updated_at timestamptz not null default now();

create trigger set_saved_quotes_updated_at
  before update on public.saved_quotes
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- 6) Performance indexes for common access/RLS patterns
-- ------------------------------------------------------------
create index group_members_user_group_idx
  on public.group_members (user_id, group_id);

create index group_members_user_updated_idx
  on public.group_members (user_id, updated_at desc);

create index group_shared_habits_group_shared_user_habit_idx
  on public.group_shared_habits (group_id, shared, user_id, habit_id);

create index group_shared_habits_user_habit_group_idx
  on public.group_shared_habits (user_id, habit_id, group_id);

create index habit_completions_user_habit_updated_idx
  on public.habit_completions (user_id, habit_id, updated_at desc);

create index saved_quotes_user_updated_idx
  on public.saved_quotes (user_id, updated_at desc);

create index nudges_sender_day_idx
  on public.nudges (from_user_id, day desc);
