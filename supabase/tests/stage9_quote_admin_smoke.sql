-- Stage 9 smoke verification
-- Run with: psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/stage9_quote_admin_smoke.sql

begin;
set local role postgres;

with ids as (
  select
    gen_random_uuid() as admin_id,
    gen_random_uuid() as editor_id
)
insert into auth.users (
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data
)
select
  admin_id,
  'authenticated',
  'authenticated',
  'stage9-admin@example.com',
  crypt('password', gen_salt('bf')),
  now(),
  now(),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb
from ids
union all
select
  editor_id,
  'authenticated',
  'authenticated',
  'stage9-editor@example.com',
  crypt('password', gen_salt('bf')),
  now(),
  now(),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb
from ids;

do $$
declare
  v_admin_id uuid;
  v_editor_id uuid;
  v_set_id uuid;
  v_quote_id uuid;
  v_locale text;
  v_text text;
  v_fallback_locale text;
  v_day date := date '2026-02-22';
  v_denied boolean := false;
begin
  select id into v_admin_id
  from auth.users
  where email = 'stage9-admin@example.com'
  limit 1;

  select id into v_editor_id
  from auth.users
  where email = 'stage9-editor@example.com'
  limit 1;

  update public.profiles
  set is_admin = true
  where id = v_admin_id;

  insert into public.admin_allowlist(email, role)
  values ('stage9-admin@example.com', 'owner');

  if not public.is_allowlisted_admin(v_admin_id) then
    raise exception 'allowlisted admin helper should return true for owner';
  end if;

  if public.is_allowlisted_admin(v_editor_id) then
    raise exception 'allowlisted admin helper should return false for non-admin';
  end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config('request.jwt.claim.sub', v_admin_id::text, true);

  insert into public.quote_sets(status, created_by)
  values ('draft', v_admin_id)
  returning id into v_set_id;

  insert into public.quotes (quote_set_id, locale, text, source, draft, active)
  values
    (v_set_id, 'kk', 'Амалдардың ең абзалы — тұрақтысы.', 'Бухари', true, true),
    (v_set_id, 'ru', 'Лучшие дела — те, что совершаются постоянно.', 'Бухари', true, true),
    (v_set_id, 'en', 'The best deeds are the most consistent.', 'Bukhari', true, true);

  update public.quote_sets
  set status = 'approved', approved_by = v_admin_id, approved_at = now()
  where id = v_set_id;

  update public.quotes
  set draft = false
  where quote_set_id = v_set_id;

  insert into public.quote_day_overrides(day_date, quote_set_id, created_by)
  values (v_day, v_set_id, v_admin_id)
  on conflict (day_date)
  do update set quote_set_id = excluded.quote_set_id, created_by = excluded.created_by;

  select quote_id, locale, text
    into v_quote_id, v_locale, v_text
  from public.get_quote_for_day('kk', v_day)
  limit 1;

  if v_quote_id is null then
    raise exception 'get_quote_for_day did not return a row for explicit override day';
  end if;

  if v_locale <> 'kk' then
    raise exception 'Expected kk locale quote, got %', v_locale;
  end if;

  select locale
    into v_fallback_locale
  from public.get_quote_for_day('xx', v_day)
  limit 1;

  if v_fallback_locale not in ('kk', 'ru', 'en') then
    raise exception 'Locale fallback failed for unsupported locale';
  end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config('request.jwt.claim.sub', v_editor_id::text, true);

  begin
    insert into public.quote_sets(status, created_by)
    values ('draft', v_editor_id);
  exception
    when others then
      v_denied := true;
  end;

  if not v_denied then
    raise exception 'Non-allowlisted user should not insert quote_sets directly';
  end if;
end;
$$;

rollback;
