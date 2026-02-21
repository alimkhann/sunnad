-- Sunnad — Migration 12: Stage 9 quote admin model

-- ------------------------------------------------------------
-- 1) Core editorial grouping and override tables
-- ------------------------------------------------------------
create table if not exists public.quote_sets (
  id uuid primary key default gen_random_uuid(),
  status text not null default 'draft'
    constraint quote_sets_status_check check (status in ('draft', 'approved', 'archived')),
  created_by uuid references public.profiles(id) on delete set null,
  approved_by uuid references public.profiles(id) on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_quote_sets_updated_at
  before update on public.quote_sets
  for each row execute function public.set_updated_at();

create index if not exists quote_sets_status_created_idx
  on public.quote_sets (status, created_at);

create table if not exists public.quote_day_overrides (
  day_date date primary key,
  quote_set_id uuid not null references public.quote_sets(id) on delete cascade,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_quote_day_overrides_updated_at
  before update on public.quote_day_overrides
  for each row execute function public.set_updated_at();

create index if not exists quote_day_overrides_quote_set_idx
  on public.quote_day_overrides (quote_set_id);

create table if not exists public.admin_allowlist (
  email text primary key,
  role text not null default 'editor'
    constraint admin_allowlist_role_check check (role in ('editor', 'owner')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint admin_allowlist_email_normalized check (email = lower(trim(email)))
);

create trigger set_admin_allowlist_updated_at
  before update on public.admin_allowlist
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- 2) Extend existing quotes table while preserving compatibility
-- ------------------------------------------------------------
alter table public.quotes
  add column if not exists quote_set_id uuid references public.quote_sets(id) on delete cascade,
  add column if not exists draft boolean not null default false;

-- Backfill one quote_set per legacy quote row to preserve existing IDs and behavior.
insert into public.quote_sets (id, status, created_at, updated_at)
select q.id, 'approved', q.created_at, q.updated_at
from public.quotes q
where q.quote_set_id is null
  and not exists (
    select 1
    from public.quote_sets qs
    where qs.id = q.id
  );

update public.quotes
set quote_set_id = id
where quote_set_id is null;

alter table public.quotes
  alter column quote_set_id set not null;

create unique index if not exists quotes_quote_set_locale_uidx
  on public.quotes (quote_set_id, locale);

create index if not exists quotes_quote_set_active_idx
  on public.quotes (quote_set_id, active, draft, updated_at desc);

-- ------------------------------------------------------------
-- 3) Admin identity helper for allowlist+role gate
-- ------------------------------------------------------------
create or replace function public.is_allowlisted_admin(p_user_id uuid default null)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1
    from public.profiles p
    join auth.users u
      on u.id = p.id
    join public.admin_allowlist aa
      on aa.email = lower(trim(coalesce(u.email, '')))
    where p.id = coalesce(p_user_id, auth.uid())
      and p.is_admin = true
  );
$$;

revoke all on function public.is_allowlisted_admin(uuid) from public;
grant execute on function public.is_allowlisted_admin(uuid) to authenticated;

-- ------------------------------------------------------------
-- 4) Quote-of-day RPC (global day in Asia/Almaty)
-- ------------------------------------------------------------
create or replace function public.get_quote_for_day(
  p_locale text,
  p_day date default null
)
returns table (
  quote_set_id uuid,
  quote_id uuid,
  locale text,
  text text,
  source text,
  day_date date,
  is_override boolean
)
language plpgsql
security definer
set search_path = ''
stable
as $$
declare
  v_locale text := lower(trim(coalesce(p_locale, 'en')));
  v_day date := coalesce(p_day, timezone('Asia/Almaty', now())::date);
  v_quote_set_id uuid;
  v_count integer;
  v_index integer;
begin
  if v_locale not in ('en', 'ru', 'kk') then
    v_locale := 'en';
  end if;

  select qdo.quote_set_id
    into v_quote_set_id
  from public.quote_day_overrides qdo
  join public.quote_sets qs
    on qs.id = qdo.quote_set_id
  where qdo.day_date = v_day
    and qs.status = 'approved'
  limit 1;

  if v_quote_set_id is null then
    select count(*)
      into v_count
    from public.quote_sets qs
    where qs.status = 'approved'
      and exists (
        select 1
        from public.quotes q
        where q.quote_set_id = qs.id
          and q.active = true
          and q.draft = false
      );

    if coalesce(v_count, 0) = 0 then
      return;
    end if;

    v_index := mod(abs((('x' || substr(md5(v_day::text), 1, 8))::bit(32)::int)), v_count);

    select qs.id
      into v_quote_set_id
    from public.quote_sets qs
    where qs.status = 'approved'
      and exists (
        select 1
        from public.quotes q
        where q.quote_set_id = qs.id
          and q.active = true
          and q.draft = false
      )
    order by qs.created_at, qs.id
    offset v_index
    limit 1;
  end if;

  return query
  with picked as (
    select
      q.id,
      q.locale,
      q.text,
      q.source
    from public.quotes q
    where q.quote_set_id = v_quote_set_id
      and q.active = true
      and q.draft = false
      and q.locale in (v_locale, 'kk', 'ru', 'en')
    order by case q.locale
      when v_locale then 0
      when 'kk' then 1
      when 'ru' then 2
      else 3
    end,
    q.updated_at desc
    limit 1
  )
  select
    v_quote_set_id,
    p.id,
    p.locale,
    p.text,
    p.source,
    v_day,
    exists (
      select 1
      from public.quote_day_overrides qdo
      where qdo.day_date = v_day
        and qdo.quote_set_id = v_quote_set_id
    ) as is_override
  from picked p;
end;
$$;

revoke all on function public.get_quote_for_day(text, date) from public;
grant execute on function public.get_quote_for_day(text, date) to anon, authenticated;

-- ------------------------------------------------------------
-- 5) RLS for new tables (admin-only direct access)
-- ------------------------------------------------------------
alter table public.quote_sets enable row level security;
alter table public.quote_day_overrides enable row level security;
alter table public.admin_allowlist enable row level security;

drop policy if exists "Admins can read quote sets" on public.quote_sets;
create policy "Admins can read quote sets"
  on public.quote_sets for select
  using (public.is_allowlisted_admin((select auth.uid())));

drop policy if exists "Admins can manage quote sets" on public.quote_sets;
create policy "Admins can manage quote sets"
  on public.quote_sets for all
  using (public.is_allowlisted_admin((select auth.uid())))
  with check (public.is_allowlisted_admin((select auth.uid())));

drop policy if exists "Admins can read quote day overrides" on public.quote_day_overrides;
create policy "Admins can read quote day overrides"
  on public.quote_day_overrides for select
  using (public.is_allowlisted_admin((select auth.uid())));

drop policy if exists "Admins can manage quote day overrides" on public.quote_day_overrides;
create policy "Admins can manage quote day overrides"
  on public.quote_day_overrides for all
  using (public.is_allowlisted_admin((select auth.uid())))
  with check (public.is_allowlisted_admin((select auth.uid())));

drop policy if exists "Admins can read admin allowlist" on public.admin_allowlist;
create policy "Admins can read admin allowlist"
  on public.admin_allowlist for select
  using (public.is_allowlisted_admin((select auth.uid())));

drop policy if exists "Owners can manage admin allowlist" on public.admin_allowlist;
create policy "Owners can manage admin allowlist"
  on public.admin_allowlist for all
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

-- Keep quotes read policy behavior compatible for clients; admin mutations remain policy-protected.
drop policy if exists "Anyone can read active quotes" on public.quotes;
create policy "Anyone can read active quotes"
  on public.quotes for select
  using (active = true and draft = false);
