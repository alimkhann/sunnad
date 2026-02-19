-- ============================================================
-- Sunnad — Migration 4: Fix recursive group_members RLS policy
-- ============================================================

create or replace function public.is_group_member(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.group_members gm
    where gm.group_id = p_group_id
      and gm.user_id = auth.uid()
  );
$$;

revoke all on function public.is_group_member(uuid) from public;
grant execute on function public.is_group_member(uuid) to authenticated;

drop policy if exists "Members can see fellow members" on public.group_members;

create policy "Members can see fellow members"
  on public.group_members for select
  using (public.is_group_member(group_id));
