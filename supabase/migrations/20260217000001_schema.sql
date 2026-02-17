-- ============================================================
-- Sunnad — Migration 1: Schema + Constraints + Indexes + Triggers
-- Offline-first habit tracker with group sharing & nudges
-- ============================================================

-- Enable pgcrypto for gen_random_uuid()
create extension if not exists "pgcrypto";

-- ------------------------------------------------------------
-- HELPER: auto-update updated_at columns (defined first, used by triggers below)
-- ------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ------------------------------------------------------------
-- 1. PROFILES (identity)
-- ------------------------------------------------------------
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  username    text unique,
  is_admin    boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.profiles is 'User profile linked 1-to-1 with auth.users';

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id)
  values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create trigger set_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- 2. HABITS
-- ------------------------------------------------------------
create type public.habit_type as enum ('binary', 'dhikr');

create table public.habits (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  name            text not null,
  icon            text,
  type            public.habit_type not null default 'binary',
  target_count    int,                               -- NULL for binary; required >0 for dhikr
  schedule        text not null default 'daily',     -- daily | weekly | custom
  weekdays        smallint[] default '{}'::smallint[],  -- 1=Mon..7=Sun (ISO)
  reminder_enabled boolean not null default false,
  reminder_time   time,
  sort_order      int not null default 0,
  archived        boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  -- Dhikr habits must have a positive target
  constraint dhikr_target_required
    check (type <> 'dhikr' or (target_count is not null and target_count > 0)),

  -- If reminder is enabled, a time must be set
  constraint reminder_requires_time
    check (reminder_enabled = false or reminder_time is not null),

  -- Weekly schedule requires at least 1 weekday selected
  constraint weekly_requires_weekdays
    check (schedule <> 'weekly' or (weekdays is not null and array_length(weekdays, 1) between 1 and 7)),

  -- Weekdays must be ISO 1-7
  constraint weekdays_valid_range
    check (weekdays is null or weekdays <@ array[1,2,3,4,5,6,7]::smallint[])
);

comment on table public.habits is 'User-defined habits (binary or dhikr counter)';

-- Today list & manage list
create index habits_user_archived_sort_idx
  on public.habits (user_id, archived, sort_order);

create trigger set_habits_updated_at
  before update on public.habits
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- 3. HABIT COMPLETIONS
-- ------------------------------------------------------------
create table public.habit_completions (
  user_id       uuid not null references public.profiles(id) on delete cascade,
  habit_id      uuid not null references public.habits(id) on delete cascade,
  day_date      date not null,
  value         int not null default 0,   -- 0/1 for binary, 0..target_count for dhikr
  completed_at  timestamptz,
  updated_at    timestamptz not null default now(),

  primary key (user_id, habit_id, day_date)
);

comment on table public.habit_completions is 'Daily completion records — one row per habit per day';

-- Pull completions for a habit over time / "today"
create index habit_completions_habit_date_idx
  on public.habit_completions (habit_id, day_date desc);

-- Pull all completions for a user on a date (Today screen)
create index habit_completions_user_date_idx
  on public.habit_completions (user_id, day_date desc);

create trigger set_completions_updated_at
  before update on public.habit_completions
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- 4. GROUPS
-- ------------------------------------------------------------
create table public.groups (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references public.profiles(id) on delete cascade,
  name        text not null,
  code        text not null unique default substr(replace(gen_random_uuid()::text, '-', ''), 1, 8),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.groups is 'Accountability groups with shareable invite code';

create trigger set_groups_updated_at
  before update on public.groups
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- 5. GROUP MEMBERS
-- ------------------------------------------------------------
create type public.group_role as enum ('owner', 'member');

create table public.group_members (
  group_id    uuid not null references public.groups(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  role        public.group_role not null default 'member',
  joined_at   timestamptz not null default now(),

  primary key (group_id, user_id)
);

comment on table public.group_members is 'Maps users to groups with their role';

-- List my groups fast
create index group_members_user_idx
  on public.group_members (user_id);

-- List members in a group
create index group_members_group_idx
  on public.group_members (group_id);

-- ------------------------------------------------------------
-- 6. GROUP SHARED HABITS
-- ------------------------------------------------------------
create table public.group_shared_habits (
  group_id    uuid not null references public.groups(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  habit_id    uuid not null references public.habits(id) on delete cascade,
  shared      boolean not null default true,
  updated_at  timestamptz not null default now(),

  primary key (group_id, user_id, habit_id)
);

comment on table public.group_shared_habits is 'Per-group, per-user habit sharing toggle';

-- Fetch shared list for a member within a group
create index group_shared_habits_group_user_idx
  on public.group_shared_habits (group_id, user_id);

-- Lookup by habit (used by RLS policies on habits/completions)
create index group_shared_habits_habit_idx
  on public.group_shared_habits (habit_id);

create trigger set_shared_habits_updated_at
  before update on public.group_shared_habits
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- 7. NUDGES (remind-a-friend)
-- ------------------------------------------------------------
create table public.nudges (
  id            uuid primary key default gen_random_uuid(),
  group_id      uuid not null references public.groups(id) on delete cascade,
  from_user_id  uuid not null references public.profiles(id) on delete cascade,
  to_user_id    uuid not null references public.profiles(id) on delete cascade,
  habit_id      uuid not null references public.habits(id) on delete cascade,
  created_at    timestamptz not null default now(),

  -- Store day explicitly (UTC day; deterministic — avoids generated-column immutability issue)
  day           date not null,

  constraint nudges_one_per_day
    unique (group_id, from_user_id, to_user_id, habit_id, day)
);

comment on table public.nudges is 'Remind-a-friend nudge log (rate-limited at DB level)';

-- Auto-populate day from created_at in UTC
create or replace function public.set_nudge_day_utc()
returns trigger
language plpgsql
as $$
begin
  new.day := (new.created_at at time zone 'utc')::date;
  return new;
end;
$$;

create trigger trg_nudges_set_day_utc
  before insert on public.nudges
  for each row execute function public.set_nudge_day_utc();

-- Group feed / audit
create index nudges_group_created_idx
  on public.nudges (group_id, created_at desc);

-- Recipient inbox
create index nudges_to_user_day_idx
  on public.nudges (to_user_id, day desc);

-- ------------------------------------------------------------
-- 8. QUOTES
-- ------------------------------------------------------------
create table public.quotes (
  id          uuid primary key default gen_random_uuid(),
  locale      text not null default 'en'
    constraint quotes_locale_check check (locale in ('en', 'kk', 'ru')),
  text        text not null,
  source      text,                               -- attribution
  sort_order  int not null default 0,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.quotes is 'Curated inspirational quotes';

-- Fetch active quotes for a locale, ordered
create index quotes_locale_active_sort_idx
  on public.quotes (locale, active, sort_order);

create trigger set_quotes_updated_at
  before update on public.quotes
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- 9. SAVED QUOTES
-- ------------------------------------------------------------
create table public.saved_quotes (
  user_id     uuid not null references public.profiles(id) on delete cascade,
  quote_id    uuid not null references public.quotes(id) on delete cascade,
  saved_at    timestamptz not null default now(),

  primary key (user_id, quote_id)
);

comment on table public.saved_quotes is 'User bookmarked quotes';

create index saved_quotes_user_idx
  on public.saved_quotes (user_id, saved_at desc);

-- ------------------------------------------------------------
-- 10. DEVICE TOKENS (push notifications)
-- ------------------------------------------------------------
create table public.device_tokens (
  user_id     uuid not null references public.profiles(id) on delete cascade,
  platform    text not null check (platform in ('ios', 'android', 'web')),
  token       text not null,
  updated_at  timestamptz not null default now(),

  primary key (user_id, token)
);

comment on table public.device_tokens is 'FCM / APNs push notification tokens';

create index device_tokens_user_idx
  on public.device_tokens (user_id);

create trigger set_device_tokens_updated_at
  before update on public.device_tokens
  for each row execute function public.set_updated_at();
