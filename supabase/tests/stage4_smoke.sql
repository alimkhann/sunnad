-- Stage 4 smoke verification
-- Run with: psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/stage4_smoke.sql

begin;

set local role postgres;

-- Create two test auth users + profiles
with u as (
  select
    gen_random_uuid() as owner_id,
    gen_random_uuid() as member_id
)
insert into auth.users (
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data
)
select
  owner_id,
  'authenticated',
  'authenticated',
  'stage4-owner@example.com',
  crypt('password', gen_salt('bf')),
  now(),
  now(),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb
from u
union all
select
  member_id,
  'authenticated',
  'authenticated',
  'stage4-member@example.com',
  crypt('password', gen_salt('bf')),
  now(),
  now(),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb
from u;

do $$
declare
  v_owner_id uuid;
  v_member_id uuid;
  v_group_id uuid;
  v_joined_group_id uuid;
  v_code text;
  v_mixed_code text;
  v_habit_id uuid;
  v_shared_count int;
begin
  select id into v_owner_id
  from auth.users
  where email = 'stage4-owner@example.com'
  limit 1;

  select id into v_member_id
  from auth.users
  where email = 'stage4-member@example.com'
  limit 1;

  if v_owner_id is null or v_member_id is null then
    raise exception 'Failed to set up test profiles';
  end if;

  -- RPC: create group with owner membership
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config('request.jwt.claim.sub', v_owner_id::text, true);

  select public.create_group_with_owner('Stage4 Smoke Group') into v_group_id;

  if v_group_id is null then
    raise exception 'create_group_with_owner did not return group id';
  end if;

  select code into v_code from public.groups where id = v_group_id;
  if v_code is null then
    raise exception 'Group code not found for created group';
  end if;

  -- mixed-case join path
  v_mixed_code := lower(substr(v_code, 1, 2)) || upper(substr(v_code, 3));

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config('request.jwt.claim.sub', v_member_id::text, true);

  select public.join_group_by_code(v_mixed_code) into v_joined_group_id;

  if v_joined_group_id is distinct from v_group_id then
    raise exception 'join_group_by_code returned unexpected group id';
  end if;

  if not exists (
    select 1 from public.group_members
    where group_id = v_group_id and user_id = v_member_id
  ) then
    raise exception 'Member was not inserted into group_members';
  end if;

  -- Member creates a habit and shares it with group
  insert into public.habits (
    user_id,
    name,
    icon,
    type,
    target_count,
    schedule,
    weekdays,
    reminder_enabled,
    sort_order
  )
  values (
    v_member_id,
    'Stage4 shared habit',
    'star.fill',
    'binary',
    null,
    'daily',
    '{}'::smallint[],
    false,
    0
  )
  returning id into v_habit_id;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config('request.jwt.claim.sub', v_member_id::text, true);

  insert into public.group_shared_habits (group_id, user_id, habit_id, shared)
  values (v_group_id, v_member_id, v_habit_id, true)
  on conflict (group_id, user_id, habit_id)
  do update set shared = excluded.shared;

  -- Owner can see shared row via membership policy
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config('request.jwt.claim.sub', v_owner_id::text, true);

  select count(*) into v_shared_count
  from public.group_shared_habits
  where group_id = v_group_id
    and user_id = v_member_id
    and habit_id = v_habit_id
    and shared = true;

  if v_shared_count <> 1 then
    raise exception 'Owner cannot read shared habit row through RLS';
  end if;

  -- Nudge uniqueness/day behavior
  insert into public.nudges (group_id, from_user_id, to_user_id, habit_id, day)
  values (v_group_id, v_owner_id, v_member_id, v_habit_id, current_date);

  begin
    insert into public.nudges (group_id, from_user_id, to_user_id, habit_id, day)
    values (v_group_id, v_owner_id, v_member_id, v_habit_id, current_date);
    raise exception 'Expected unique violation for duplicate nudge/day was not raised';
  exception
    when unique_violation then
      null;
  end;

  -- Account deletion RPC removes the authenticated user account row.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config('request.jwt.claim.sub', v_member_id::text, true);
  perform public.delete_own_account();

  execute 'set local role postgres';
  if exists (select 1 from auth.users where id = v_member_id) then
    raise exception 'delete_own_account did not remove auth user';
  end if;

  execute 'reset role';
end $$;

rollback;
