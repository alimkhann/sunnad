-- ============================================================
-- Sunnad — Migration 2: RLS + Policies + Join Flow
-- ============================================================

-- ------------------------------------------------------------
-- 1. PROFILES — RLS
-- ------------------------------------------------------------
alter table public.profiles enable row level security;

-- Users can see own profile, or profiles of people sharing a group
create policy "Users can view own profile or group members"
  on public.profiles for select
  using (
    id = auth.uid()
    or exists (
      select 1
      from public.group_members gm_me
      join public.group_members gm_other
        on gm_me.group_id = gm_other.group_id
      where gm_me.user_id = auth.uid()
        and gm_other.user_id = public.profiles.id
    )
  );

create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- ------------------------------------------------------------
-- 2. HABITS — RLS
-- ------------------------------------------------------------
alter table public.habits enable row level security;

-- Own habits + habits shared with groups the user belongs to
create policy "Users can view own habits or habits shared with their groups"
  on public.habits for select
  using (
    user_id = auth.uid()
    or exists (
      select 1
      from public.group_shared_habits gsh
      join public.group_members gm
        on gm.group_id = gsh.group_id
      where gsh.habit_id = public.habits.id
        and gsh.user_id = public.habits.user_id
        and gsh.shared = true
        and gm.user_id = auth.uid()
    )
  );

create policy "Users can insert own habits"
  on public.habits for insert
  with check (auth.uid() = user_id);

create policy "Users can update own habits"
  on public.habits for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete own habits"
  on public.habits for delete
  using (auth.uid() = user_id);

-- ------------------------------------------------------------
-- 3. HABIT COMPLETIONS — RLS
-- ------------------------------------------------------------
alter table public.habit_completions enable row level security;

-- Own completions + completions of shared habits in groups
create policy "Users can view own completions or shared completions in groups"
  on public.habit_completions for select
  using (
    user_id = auth.uid()
    or exists (
      select 1
      from public.group_shared_habits gsh
      join public.group_members gm
        on gm.group_id = gsh.group_id
      where gsh.habit_id = public.habit_completions.habit_id
        and gsh.user_id = public.habit_completions.user_id
        and gsh.shared = true
        and gm.user_id = auth.uid()
    )
  );

-- Hardened: user can only insert completions for their own habits
create policy "Users can insert own completions for their habits"
  on public.habit_completions for insert
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.habits h
      where h.id = habit_id and h.user_id = auth.uid()
    )
  );

-- Hardened: user can only update completions for their own habits
create policy "Users can update own completions for their habits"
  on public.habit_completions for update
  using (auth.uid() = user_id)
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.habits h
      where h.id = habit_id and h.user_id = auth.uid()
    )
  );

create policy "Users can delete own completions"
  on public.habit_completions for delete
  using (auth.uid() = user_id);

-- ------------------------------------------------------------
-- 4. GROUPS — RLS
-- ------------------------------------------------------------
alter table public.groups enable row level security;

-- Members can see groups they belong to
create policy "Members can read their groups"
  on public.groups for select
  using (
    id in (select group_id from public.group_members where user_id = auth.uid())
  );

create policy "Authenticated users can create groups"
  on public.groups for insert
  with check (auth.uid() = owner_id);

create policy "Owner can update group"
  on public.groups for update
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create policy "Owner can delete group"
  on public.groups for delete
  using (auth.uid() = owner_id);

-- ------------------------------------------------------------
-- 5. GROUP MEMBERS — RLS
-- ------------------------------------------------------------
alter table public.group_members enable row level security;

create policy "Members can see fellow members"
  on public.group_members for select
  using (
    group_id in (select group_id from public.group_members where user_id = auth.uid())
  );

create policy "Users can join groups (insert themselves)"
  on public.group_members for insert
  with check (auth.uid() = user_id);

create policy "Owner or self can remove membership"
  on public.group_members for delete
  using (
    auth.uid() in (
      select owner_id from public.groups where id = group_id
    )
    or auth.uid() = user_id   -- members can leave
  );

-- ------------------------------------------------------------
-- 6. GROUP SHARED HABITS — RLS
-- ------------------------------------------------------------
alter table public.group_shared_habits enable row level security;

-- Group members can see shared habits of fellow members
create policy "Members can see shared habits in their groups"
  on public.group_shared_habits for select
  using (
    group_id in (select group_id from public.group_members where user_id = auth.uid())
  );

create policy "Users can share own habits"
  on public.group_shared_habits for insert
  with check (auth.uid() = user_id);

create policy "Users can update own sharing"
  on public.group_shared_habits for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can unshare own habits"
  on public.group_shared_habits for delete
  using (auth.uid() = user_id);

-- ------------------------------------------------------------
-- 7. NUDGES — RLS
-- ------------------------------------------------------------
alter table public.nudges enable row level security;

-- Hardened: sender must be in group, recipient must be in group,
-- and the habit must be shared by the recipient in that group
create policy "Group members can create nudges for shared habits"
  on public.nudges for insert
  with check (
    from_user_id = auth.uid()
    and exists (select 1 from public.group_members gm where gm.group_id = group_id and gm.user_id = auth.uid())
    and exists (select 1 from public.group_members gm where gm.group_id = group_id and gm.user_id = to_user_id)
    and exists (
      select 1 from public.group_shared_habits gsh
      where gsh.group_id = group_id
        and gsh.user_id = to_user_id
        and gsh.habit_id = habit_id
        and gsh.shared = true
    )
  );

create policy "Recipient or sender can read nudges"
  on public.nudges for select
  using (auth.uid() = to_user_id or auth.uid() = from_user_id);

-- ------------------------------------------------------------
-- 8. QUOTES — RLS
-- ------------------------------------------------------------
alter table public.quotes enable row level security;

create policy "Anyone can read active quotes"
  on public.quotes for select
  using (active = true);

create policy "Admins can manage quotes"
  on public.quotes for all
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
  )
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
  );

-- ------------------------------------------------------------
-- 9. SAVED QUOTES — RLS
-- ------------------------------------------------------------
alter table public.saved_quotes enable row level security;

create policy "Users can read own saved quotes"
  on public.saved_quotes for select
  using (auth.uid() = user_id);

create policy "Users can save quotes"
  on public.saved_quotes for insert
  with check (auth.uid() = user_id);

create policy "Users can unsave quotes"
  on public.saved_quotes for delete
  using (auth.uid() = user_id);

-- ------------------------------------------------------------
-- 10. DEVICE TOKENS — RLS
-- ------------------------------------------------------------
alter table public.device_tokens enable row level security;

create policy "Users can read own tokens"
  on public.device_tokens for select
  using (auth.uid() = user_id);

create policy "Users can register tokens"
  on public.device_tokens for insert
  with check (auth.uid() = user_id);

create policy "Users can update own tokens"
  on public.device_tokens for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete own tokens"
  on public.device_tokens for delete
  using (auth.uid() = user_id);

-- ------------------------------------------------------------
-- 11. RPC: join_group_by_code (security definer)
-- ------------------------------------------------------------
-- Allows an authenticated user to join a group using its invite code.
-- Bypasses RLS so the user can look up the group even if not yet a member.
create or replace function public.join_group_by_code(invite_code text)
returns uuid
language plpgsql
security definer set search_path = ''
as $$
declare
  v_group_id uuid;
  v_user_id  uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select id into v_group_id
  from public.groups
  where code = invite_code;

  if v_group_id is null then
    raise exception 'Invalid invite code';
  end if;

  insert into public.group_members (group_id, user_id, role)
  values (v_group_id, v_user_id, 'member')
  on conflict (group_id, user_id) do nothing;

  return v_group_id;
end;
$$;
