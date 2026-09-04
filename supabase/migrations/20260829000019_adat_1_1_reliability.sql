-- ============================================================
-- Adat 1.1: reliable local days, dhikr, and group nudges
-- ============================================================

-- Profile context used for localized notifications and member-local day keys.
alter table public.profiles
  add column if not exists time_zone text not null default 'UTC',
  add column if not exists locale text not null default 'en',
  add column if not exists group_nudges_enabled boolean not null default true;

alter table public.profiles
  drop constraint if exists profiles_locale_check;

alter table public.profiles
  add constraint profiles_locale_check
  check (locale in ('en', 'ru', 'kk'));

-- One current push registration per signed-in account and app installation.
alter table public.device_tokens
  add column if not exists installation_id uuid;

create unique index if not exists device_tokens_user_installation_uidx
  on public.device_tokens (user_id, installation_id)
  where installation_id is not null;

-- A dhikr habit owns one phrase. Existing habits migrate to SubhanAllah.
alter table public.habits
  add column if not exists dhikr_phrase_key text,
  add column if not exists dhikr_custom_phrase text;

update public.habits
set dhikr_phrase_key = 'dhikr.choice.subhanallah'
where type = 'dhikr'
  and nullif(btrim(dhikr_phrase_key), '') is null
  and nullif(btrim(dhikr_custom_phrase), '') is null;

alter table public.habits
  drop constraint if exists habits_dhikr_phrase_required;

alter table public.habits
  add constraint habits_dhikr_phrase_required
  check (
    type <> 'dhikr'
    or (
      (nullif(btrim(dhikr_phrase_key), '') is not null)
      <> (nullif(btrim(dhikr_custom_phrase), '') is not null)
    )
  );

-- Completion values are per local day. Dhikr may exceed its target.
alter table public.habit_completions
  add column if not exists entry_source text not null default 'normal';

alter table public.habit_completions
  drop constraint if exists habit_completions_entry_source_check;

alter table public.habit_completions
  add constraint habit_completions_entry_source_check
  check (entry_source in ('normal', 'late_check_in'));

alter table public.habit_completions
  drop constraint if exists habit_completions_nonnegative_value;

-- Older clients never intentionally wrote negatives, but normalize any damaged
-- rows before enforcing the invariant so an additive production deploy cannot
-- be blocked by legacy data.
update public.habit_completions
set value = 0
where value < 0;

alter table public.habit_completions
  add constraint habit_completions_nonnegative_value
  check (value >= 0);

-- Existing nudge rows predate delivery tracking, so retain them as delivered.
alter table public.nudges
  add column if not exists delivery_status text not null default 'delivered',
  add column if not exists failure_code text,
  add column if not exists delivered_at timestamptz;

update public.nudges
set delivered_at = coalesce(delivered_at, created_at)
where delivery_status = 'delivered';

alter table public.nudges
  alter column delivery_status set default 'pending';

alter table public.nudges
  drop constraint if exists nudges_delivery_status_check;

alter table public.nudges
  add constraint nudges_delivery_status_check
  check (delivery_status in ('pending', 'delivered', 'failed'));

-- The caller now supplies a canonical sender-local day. Retaining this trigger
-- would silently overwrite it with UTC and recreate the midnight bug.
drop trigger if exists trg_nudges_set_day_utc on public.nudges;

-- Atomically reserve a once-per-day nudge. Delivered/pending rows are duplicates;
-- failed rows can be retried without creating another audit row.
create or replace function public.reserve_group_nudge(
  p_group_id uuid,
  p_from_user_id uuid,
  p_to_user_id uuid,
  p_habit_id uuid,
  p_day date
)
returns table(nudge_id uuid, should_send boolean, result_status text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing public.nudges%rowtype;
  v_id uuid;
begin
  if not exists (
    select 1 from public.group_members
    where group_id = p_group_id and user_id = p_from_user_id
  ) then
    raise exception 'Sender is not a group member';
  end if;

  if not exists (
    select 1 from public.group_members
    where group_id = p_group_id and user_id = p_to_user_id
  ) then
    raise exception 'Recipient is not a group member';
  end if;

  if not exists (
    select 1 from public.group_shared_habits
    where group_id = p_group_id
      and user_id = p_to_user_id
      and habit_id = p_habit_id
      and shared = true
  ) then
    raise exception 'Habit is not shared by recipient';
  end if;

  select * into v_existing
  from public.nudges
  where group_id = p_group_id
    and from_user_id = p_from_user_id
    and to_user_id = p_to_user_id
    and habit_id = p_habit_id
    and day = p_day
  for update;

  if found then
    if v_existing.delivery_status = 'delivered'
      or (
        v_existing.delivery_status = 'pending'
        and v_existing.created_at >= now() - interval '5 minutes'
      ) then
      return query select v_existing.id, false, 'duplicate'::text;
      return;
    end if;

    update public.nudges
    set delivery_status = 'pending', failure_code = null, delivered_at = null, created_at = now()
    where id = v_existing.id;
    return query select v_existing.id, true, 'reserved'::text;
    return;
  end if;

  insert into public.nudges (
    group_id, from_user_id, to_user_id, habit_id, day, delivery_status
  ) values (
    p_group_id, p_from_user_id, p_to_user_id, p_habit_id, p_day, 'pending'
  )
  on conflict (group_id, from_user_id, to_user_id, habit_id, day) do nothing
  returning id into v_id;

  if v_id is not null then
    return query select v_id, true, 'reserved'::text;
    return;
  end if;

  -- A concurrent caller won the unique reservation while this transaction was
  -- checking. Wait for that row and report the same idempotent outcome.
  select * into v_existing
  from public.nudges
  where group_id = p_group_id
    and from_user_id = p_from_user_id
    and to_user_id = p_to_user_id
    and habit_id = p_habit_id
    and day = p_day
  for update;

  if v_existing.delivery_status = 'failed' then
    update public.nudges
    set delivery_status = 'pending', failure_code = null, delivered_at = null, created_at = now()
    where id = v_existing.id;
    return query select v_existing.id, true, 'reserved'::text;
  else
    return query select v_existing.id, false, 'duplicate'::text;
  end if;
end;
$$;

revoke all on function public.reserve_group_nudge(uuid, uuid, uuid, uuid, date) from public;
revoke all on function public.reserve_group_nudge(uuid, uuid, uuid, uuid, date) from anon;
revoke all on function public.reserve_group_nudge(uuid, uuid, uuid, uuid, date) from authenticated;
grant execute on function public.reserve_group_nudge(uuid, uuid, uuid, uuid, date) to service_role;
