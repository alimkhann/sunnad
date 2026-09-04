-- Adat 1.1 reliability smoke verification.
-- Run after a clean migration replay with:
-- psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/stage14_adat_1_1_reliability_smoke.sql

begin;
set local role postgres;

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data
)
values
  (
    '11111111-1111-4111-8111-111111111111', 'authenticated', 'authenticated',
    'adat11-sender@example.com', crypt('password', gen_salt('bf')), now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb
  ),
  (
    '22222222-2222-4222-8222-222222222222', 'authenticated', 'authenticated',
    'adat11-recipient@example.com', crypt('password', gen_salt('bf')), now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb
  );

do $$
declare
  v_sender uuid := '11111111-1111-4111-8111-111111111111';
  v_recipient uuid := '22222222-2222-4222-8222-222222222222';
  v_group uuid;
  v_habit uuid;
  v_nudge uuid;
  v_should_send boolean;
  v_status text;
  v_constraint_rejected boolean := false;
begin
  update public.profiles
  set time_zone = 'Asia/Almaty', locale = 'kk', group_nudges_enabled = true
  where id = v_recipient;

  begin
    update public.profiles set locale = 'xx' where id = v_recipient;
  exception when check_violation then
    v_constraint_rejected := true;
  end;
  if not v_constraint_rejected then
    raise exception 'Unsupported profile locale should be rejected';
  end if;

  insert into public.groups(owner_id, name)
  values (v_sender, 'Adat 1.1 smoke')
  returning id into v_group;

  insert into public.group_members(group_id, user_id, role)
  values (v_group, v_sender, 'owner'), (v_group, v_recipient, 'member');

  v_constraint_rejected := false;
  begin
    insert into public.habits(user_id, name, type, target_count)
    values (v_recipient, 'Invalid dhikr', 'dhikr', 1000);
  exception when check_violation then
    v_constraint_rejected := true;
  end;
  if not v_constraint_rejected then
    raise exception 'Dhikr without exactly one phrase should be rejected';
  end if;

  insert into public.habits(
    user_id, name, type, target_count, dhikr_phrase_key, dhikr_custom_phrase
  ) values (
    v_recipient, 'Custom dhikr', 'dhikr', 1000, null, 'Hasbunallahu'
  ) returning id into v_habit;

  insert into public.habit_completions(
    user_id, habit_id, day_date, value, completed_at, entry_source
  ) values (
    v_recipient, v_habit, date '2026-08-28', 1250, now(), 'late_check_in'
  );

  insert into public.group_shared_habits(group_id, user_id, habit_id, shared)
  values (v_group, v_recipient, v_habit, true);

  select nudge_id, should_send, result_status
  into v_nudge, v_should_send, v_status
  from public.reserve_group_nudge(
    v_group, v_sender, v_recipient, v_habit, date '2026-08-29'
  );
  if not v_should_send or v_status <> 'reserved' then
    raise exception 'First nudge should be reserved';
  end if;

  select nudge_id, should_send, result_status
  into v_nudge, v_should_send, v_status
  from public.reserve_group_nudge(
    v_group, v_sender, v_recipient, v_habit, date '2026-08-29'
  );
  if v_should_send or v_status <> 'duplicate' then
    raise exception 'Pending nudge should be idempotent';
  end if;

  update public.nudges
  set delivery_status = 'failed', failure_code = 'provider_unavailable'
  where id = v_nudge;

  select nudge_id, should_send, result_status
  into v_nudge, v_should_send, v_status
  from public.reserve_group_nudge(
    v_group, v_sender, v_recipient, v_habit, date '2026-08-29'
  );
  if not v_should_send or v_status <> 'reserved' then
    raise exception 'Failed nudge should be retryable';
  end if;

  insert into public.device_tokens(
    user_id, platform, token, onesignal_subscription_id, installation_id
  ) values (
    v_recipient, 'ios', 'token-one', 'subscription-one',
    '33333333-3333-4333-8333-333333333333'
  );

  v_constraint_rejected := false;
  begin
    insert into public.device_tokens(
      user_id, platform, token, onesignal_subscription_id, installation_id
    ) values (
      v_recipient, 'ios', 'token-two', 'subscription-two',
      '33333333-3333-4333-8333-333333333333'
    );
  exception when unique_violation then
    v_constraint_rejected := true;
  end;
  if not v_constraint_rejected then
    raise exception 'Only one token per user installation should be allowed';
  end if;
end;
$$;

rollback;
