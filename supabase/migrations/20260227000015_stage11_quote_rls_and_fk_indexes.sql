-- Sunnad — Migration 15: Fix quote admin mutations + advisor FK index coverage

-- Admin quote workflows require authenticated allowlisted users to manage draft rows.
drop policy if exists "Admins can read all quotes" on public.quotes;
create policy "Admins can read all quotes"
  on public.quotes for select
  to authenticated
  using (public.is_allowlisted_admin());

drop policy if exists "Admins can manage quotes" on public.quotes;
create policy "Admins can manage quotes"
  on public.quotes for all
  to authenticated
  using (public.is_allowlisted_admin())
  with check (public.is_allowlisted_admin());

-- Advisor lint requires FK columns to have supporting indexes.
create index if not exists launch_campaigns_created_by_idx
  on public.launch_campaigns (created_by);

create index if not exists quote_day_overrides_created_by_idx
  on public.quote_day_overrides (created_by);

create index if not exists quote_sets_created_by_idx
  on public.quote_sets (created_by);

create index if not exists quote_sets_approved_by_idx
  on public.quote_sets (approved_by);
