-- ============================================================
-- Sunnad — Migration 11: Advisor lint remediation (RLS perf + function search_path)
-- ============================================================

-- ------------------------------------------------------------
-- 1) Harden mutable trigger helper functions with explicit search_path
-- ------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.set_nudge_day_utc()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.day := (new.created_at at time zone 'utc')::date;
  return new;
end;
$$;

-- ------------------------------------------------------------
-- 2) Rebuild flagged RLS policies using initplan-friendly auth lookup
--    (replace auth.uid() with (select auth.uid()))
-- ------------------------------------------------------------

-- PROFILES
drop policy if exists "Users can view own profile or group members" on public.profiles;
create policy "Users can view own profile or group members"
  on public.profiles for select
  using (
    id = (select auth.uid())
    or exists (
      select 1
      from public.group_members gm_me
      join public.group_members gm_other
        on gm_me.group_id = gm_other.group_id
      where gm_me.user_id = (select auth.uid())
        and gm_other.user_id = public.profiles.id
    )
  );

drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
  on public.profiles for insert
  with check ((select auth.uid()) = id);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles for update
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- HABITS
drop policy if exists "Users can view own habits or habits shared with their groups" on public.habits;
create policy "Users can view own habits or habits shared with their groups"
  on public.habits for select
  using (
    user_id = (select auth.uid())
    or exists (
      select 1
      from public.group_shared_habits gsh
      join public.group_members gm
        on gm.group_id = gsh.group_id
      where gsh.habit_id = public.habits.id
        and gsh.user_id = public.habits.user_id
        and gsh.shared = true
        and gm.user_id = (select auth.uid())
    )
  );

drop policy if exists "Users can insert own habits" on public.habits;
create policy "Users can insert own habits"
  on public.habits for insert
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update own habits" on public.habits;
create policy "Users can update own habits"
  on public.habits for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete own habits" on public.habits;
create policy "Users can delete own habits"
  on public.habits for delete
  using ((select auth.uid()) = user_id);

-- HABIT_COMPLETIONS
drop policy if exists "Users can view own completions or shared completions in groups" on public.habit_completions;
create policy "Users can view own completions or shared completions in groups"
  on public.habit_completions for select
  using (
    user_id = (select auth.uid())
    or exists (
      select 1
      from public.group_shared_habits gsh
      join public.group_members gm
        on gm.group_id = gsh.group_id
      where gsh.habit_id = public.habit_completions.habit_id
        and gsh.user_id = public.habit_completions.user_id
        and gsh.shared = true
        and gm.user_id = (select auth.uid())
    )
  );

drop policy if exists "Users can insert own completions for their habits" on public.habit_completions;
create policy "Users can insert own completions for their habits"
  on public.habit_completions for insert
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.habits h
      where h.id = habit_id and h.user_id = (select auth.uid())
    )
  );

drop policy if exists "Users can update own completions for their habits" on public.habit_completions;
create policy "Users can update own completions for their habits"
  on public.habit_completions for update
  using ((select auth.uid()) = user_id)
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.habits h
      where h.id = habit_id and h.user_id = (select auth.uid())
    )
  );

drop policy if exists "Users can delete own completions" on public.habit_completions;
create policy "Users can delete own completions"
  on public.habit_completions for delete
  using ((select auth.uid()) = user_id);

-- GROUPS
drop policy if exists "Members can read their groups" on public.groups;
create policy "Members can read their groups"
  on public.groups for select
  using (
    id in (select group_id from public.group_members where user_id = (select auth.uid()))
  );

drop policy if exists "Authenticated users can create groups" on public.groups;
create policy "Authenticated users can create groups"
  on public.groups for insert
  with check ((select auth.uid()) = owner_id);

drop policy if exists "Owner can update group" on public.groups;
create policy "Owner can update group"
  on public.groups for update
  using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);

drop policy if exists "Owner can delete group" on public.groups;
create policy "Owner can delete group"
  on public.groups for delete
  using ((select auth.uid()) = owner_id);

-- GROUP_MEMBERS
drop policy if exists "Users can join groups (insert themselves)" on public.group_members;
create policy "Users can join groups (insert themselves)"
  on public.group_members for insert
  with check ((select auth.uid()) = user_id);

drop policy if exists "Owner or self can remove membership" on public.group_members;
create policy "Owner or self can remove membership"
  on public.group_members for delete
  using (
    (select auth.uid()) in (
      select owner_id from public.groups where id = group_id
    )
    or (select auth.uid()) = user_id
  );

-- GROUP_SHARED_HABITS
drop policy if exists "Members can see shared habits in their groups" on public.group_shared_habits;
create policy "Members can see shared habits in their groups"
  on public.group_shared_habits for select
  using (
    group_id in (select group_id from public.group_members where user_id = (select auth.uid()))
  );

drop policy if exists "Users can share own habits" on public.group_shared_habits;
create policy "Users can share own habits"
  on public.group_shared_habits for insert
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update own sharing" on public.group_shared_habits;
create policy "Users can update own sharing"
  on public.group_shared_habits for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can unshare own habits" on public.group_shared_habits;
create policy "Users can unshare own habits"
  on public.group_shared_habits for delete
  using ((select auth.uid()) = user_id);

-- NUDGES
drop policy if exists "Group members can create nudges for shared habits" on public.nudges;
create policy "Group members can create nudges for shared habits"
  on public.nudges for insert
  with check (
    from_user_id = (select auth.uid())
    and exists (
      select 1 from public.group_members gm
      where gm.group_id = group_id and gm.user_id = (select auth.uid())
    )
    and exists (
      select 1 from public.group_members gm
      where gm.group_id = group_id and gm.user_id = to_user_id
    )
    and exists (
      select 1 from public.group_shared_habits gsh
      where gsh.group_id = group_id
        and gsh.user_id = to_user_id
        and gsh.habit_id = habit_id
        and gsh.shared = true
    )
  );

drop policy if exists "Recipient or sender can read nudges" on public.nudges;
create policy "Recipient or sender can read nudges"
  on public.nudges for select
  using ((select auth.uid()) = to_user_id or (select auth.uid()) = from_user_id);

-- SAVED_QUOTES
drop policy if exists "Users can read own saved quotes" on public.saved_quotes;
create policy "Users can read own saved quotes"
  on public.saved_quotes for select
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can save quotes" on public.saved_quotes;
create policy "Users can save quotes"
  on public.saved_quotes for insert
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can unsave quotes" on public.saved_quotes;
create policy "Users can unsave quotes"
  on public.saved_quotes for delete
  using ((select auth.uid()) = user_id);

-- DEVICE_TOKENS
drop policy if exists "Users can read own tokens" on public.device_tokens;
create policy "Users can read own tokens"
  on public.device_tokens for select
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can register tokens" on public.device_tokens;
create policy "Users can register tokens"
  on public.device_tokens for insert
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update own tokens" on public.device_tokens;
create policy "Users can update own tokens"
  on public.device_tokens for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete own tokens" on public.device_tokens;
create policy "Users can delete own tokens"
  on public.device_tokens for delete
  using ((select auth.uid()) = user_id);

-- ------------------------------------------------------------
-- 3) Quotes policy overlap fix: split admin CUD from public active read
-- ------------------------------------------------------------
drop policy if exists "Admins can manage quotes" on public.quotes;

create policy "Admins can insert quotes"
  on public.quotes for insert
  with check (
    exists (
      select 1
      from public.profiles p
      where p.id = (select auth.uid())
        and p.is_admin = true
    )
  );

create policy "Admins can update quotes"
  on public.quotes for update
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = (select auth.uid())
        and p.is_admin = true
    )
  )
  with check (
    exists (
      select 1
      from public.profiles p
      where p.id = (select auth.uid())
        and p.is_admin = true
    )
  );

create policy "Admins can delete quotes"
  on public.quotes for delete
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = (select auth.uid())
        and p.is_admin = true
    )
  );
