-- Sunnad — Migration 16: Consolidate permissive SELECT policies for admin tables
-- Purpose: avoid multiple permissive SELECT policies on the same role/action while
-- preserving admin/owner authorization semantics.

-- ------------------------------------------------------------
-- quotes: preserve public active-read + admin full-read without duplicate SELECT
-- ------------------------------------------------------------
drop policy if exists "Admins can read all quotes" on public.quotes;
drop policy if exists "Admins can manage quotes" on public.quotes;
drop policy if exists "Admins can insert quotes" on public.quotes;
drop policy if exists "Admins can update quotes" on public.quotes;
drop policy if exists "Admins can delete quotes" on public.quotes;
drop policy if exists "Anyone can read active quotes" on public.quotes;

create policy "Anyone can read active quotes"
  on public.quotes for select
  using (
    (active = true and draft = false)
    or public.is_allowlisted_admin((select auth.uid()))
  );

create policy "Admins can insert quotes"
  on public.quotes for insert
  to authenticated
  with check (public.is_allowlisted_admin((select auth.uid())));

create policy "Admins can update quotes"
  on public.quotes for update
  to authenticated
  using (public.is_allowlisted_admin((select auth.uid())))
  with check (public.is_allowlisted_admin((select auth.uid())));

create policy "Admins can delete quotes"
  on public.quotes for delete
  to authenticated
  using (public.is_allowlisted_admin((select auth.uid())));

-- ------------------------------------------------------------
-- quote_sets: keep admin SELECT, split admin CUD into explicit policies
-- ------------------------------------------------------------
drop policy if exists "Admins can manage quote sets" on public.quote_sets;
drop policy if exists "Admins can insert quote sets" on public.quote_sets;
drop policy if exists "Admins can update quote sets" on public.quote_sets;
drop policy if exists "Admins can delete quote sets" on public.quote_sets;

create policy "Admins can insert quote sets"
  on public.quote_sets for insert
  to authenticated
  with check (public.is_allowlisted_admin((select auth.uid())));

create policy "Admins can update quote sets"
  on public.quote_sets for update
  to authenticated
  using (public.is_allowlisted_admin((select auth.uid())))
  with check (public.is_allowlisted_admin((select auth.uid())));

create policy "Admins can delete quote sets"
  on public.quote_sets for delete
  to authenticated
  using (public.is_allowlisted_admin((select auth.uid())));

-- ------------------------------------------------------------
-- quote_day_overrides: keep admin SELECT, split admin CUD into explicit policies
-- ------------------------------------------------------------
drop policy if exists "Admins can manage quote day overrides" on public.quote_day_overrides;
drop policy if exists "Admins can insert quote day overrides" on public.quote_day_overrides;
drop policy if exists "Admins can update quote day overrides" on public.quote_day_overrides;
drop policy if exists "Admins can delete quote day overrides" on public.quote_day_overrides;

create policy "Admins can insert quote day overrides"
  on public.quote_day_overrides for insert
  to authenticated
  with check (public.is_allowlisted_admin((select auth.uid())));

create policy "Admins can update quote day overrides"
  on public.quote_day_overrides for update
  to authenticated
  using (public.is_allowlisted_admin((select auth.uid())))
  with check (public.is_allowlisted_admin((select auth.uid())));

create policy "Admins can delete quote day overrides"
  on public.quote_day_overrides for delete
  to authenticated
  using (public.is_allowlisted_admin((select auth.uid())));

-- ------------------------------------------------------------
-- admin_allowlist: keep admin SELECT, split owner CUD into explicit policies
-- ------------------------------------------------------------
drop policy if exists "Owners can manage admin allowlist" on public.admin_allowlist;
drop policy if exists "Owners can insert admin allowlist" on public.admin_allowlist;
drop policy if exists "Owners can update admin allowlist" on public.admin_allowlist;
drop policy if exists "Owners can delete admin allowlist" on public.admin_allowlist;

create policy "Owners can insert admin allowlist"
  on public.admin_allowlist for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.profiles p
      join auth.users u
        on u.id = p.id
      join public.admin_allowlist aa
        on aa.email = lower(trim(coalesce(u.email, '')))
      where p.id = (select auth.uid())
        and p.is_admin = true
        and aa.role = 'owner'
    )
  );

create policy "Owners can update admin allowlist"
  on public.admin_allowlist for update
  to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      join auth.users u
        on u.id = p.id
      join public.admin_allowlist aa
        on aa.email = lower(trim(coalesce(u.email, '')))
      where p.id = (select auth.uid())
        and p.is_admin = true
        and aa.role = 'owner'
    )
  )
  with check (
    exists (
      select 1
      from public.profiles p
      join auth.users u
        on u.id = p.id
      join public.admin_allowlist aa
        on aa.email = lower(trim(coalesce(u.email, '')))
      where p.id = (select auth.uid())
        and p.is_admin = true
        and aa.role = 'owner'
    )
  );

create policy "Owners can delete admin allowlist"
  on public.admin_allowlist for delete
  to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      join auth.users u
        on u.id = p.id
      join public.admin_allowlist aa
        on aa.email = lower(trim(coalesce(u.email, '')))
      where p.id = (select auth.uid())
        and p.is_admin = true
        and aa.role = 'owner'
    )
  );
