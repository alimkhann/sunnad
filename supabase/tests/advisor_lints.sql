-- Supabase Advisor-style SQL lint checks
-- Run with: psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/advisor_lints.sql

begin;

-- 1) Fail if any public table with user data has RLS disabled.
do $$
declare
  v_count int;
begin
  select count(*)
    into v_count
  from pg_class c
  join pg_namespace n
    on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind = 'r'
    and c.relname not in ('schema_migrations')
    and c.relrowsecurity = false;

  if v_count > 0 then
    raise exception 'RLS check failed: % public tables have RLS disabled', v_count;
  end if;
end;
$$;

-- 2) Fail if SECURITY DEFINER functions in public do not pin search_path.
do $$
declare
  v_count int;
begin
  select count(*)
    into v_count
  from pg_proc p
  join pg_namespace n
    on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prosecdef = true
    and not exists (
      select 1
      from unnest(coalesce(p.proconfig, '{}')) cfg
      where cfg like 'search_path=%'
    );

  if v_count > 0 then
    raise exception 'Function hardening check failed: % SECURITY DEFINER functions missing explicit search_path', v_count;
  end if;
end;
$$;

-- 3) Fail if any public foreign key has no supporting index.
do $$
declare
  v_count int;
begin
  with fk as (
    select
      con.oid,
      con.conname,
      con.conrelid,
      con.conkey
    from pg_constraint con
    join pg_namespace n
      on n.oid = con.connamespace
    where con.contype = 'f'
      and n.nspname = 'public'
  ),
  fk_without_index as (
    select fk.oid
    from fk
    where not exists (
      select 1
      from pg_index idx
      where idx.indrelid = fk.conrelid
        and idx.indisvalid = true
        and idx.indisready = true
        and (
          select bool_and(attnum = any(idx.indkey::int2[]))
          from unnest(fk.conkey) attnum
        )
    )
  )
  select count(*)
    into v_count
  from fk_without_index;

  if v_count > 0 then
    raise exception 'Index coverage check failed: % foreign keys without supporting index', v_count;
  end if;
end;
$$;

-- 4) Report overlapping permissive policies by table/cmd for visibility.
-- This is informational to monitor policy complexity and potential planner impact.
select
  n.nspname as schema_name,
  c.relname as table_name,
  case p.polcmd
    when 'r' then 'select'
    when 'a' then 'insert'
    when 'w' then 'update'
    when 'd' then 'delete'
    when '*' then 'all'
    else p.polcmd::text
  end as command,
  count(*) as permissive_policy_count
from pg_policy p
join pg_class c
  on c.oid = p.polrelid
join pg_namespace n
  on n.oid = c.relnamespace
where n.nspname = 'public'
  and p.polpermissive = true
group by n.nspname, c.relname, p.polcmd
having count(*) > 1
order by table_name, command;

rollback;
