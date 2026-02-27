-- Stage 10 landing waitlist smoke verification
-- Run with: psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/stage10_landing_smoke.sql

begin;
set local role postgres;

-- ============================================================
-- 1) Verify tables exist with expected columns
-- ============================================================
do $$
begin
  -- waitlist_subscribers
  assert (select count(*) from information_schema.tables
    where table_schema = 'public' and table_name = 'waitlist_subscribers') = 1,
    'waitlist_subscribers table should exist';

  -- launch_campaigns
  assert (select count(*) from information_schema.tables
    where table_schema = 'public' and table_name = 'launch_campaigns') = 1,
    'launch_campaigns table should exist';

  -- launch_sends
  assert (select count(*) from information_schema.tables
    where table_schema = 'public' and table_name = 'launch_sends') = 1,
    'launch_sends table should exist';

  raise notice 'PASS: all three tables exist';
end $$;

-- ============================================================
-- 2) Verify RLS is enabled
-- ============================================================
do $$
begin
  assert (select rowsecurity from pg_tables where schemaname = 'public' and tablename = 'waitlist_subscribers'),
    'RLS should be enabled on waitlist_subscribers';
  assert (select rowsecurity from pg_tables where schemaname = 'public' and tablename = 'launch_campaigns'),
    'RLS should be enabled on launch_campaigns';
  assert (select rowsecurity from pg_tables where schemaname = 'public' and tablename = 'launch_sends'),
    'RLS should be enabled on launch_sends';

  raise notice 'PASS: RLS enabled on all tables';
end $$;

-- ============================================================
-- 3) Verify check constraints
-- ============================================================
do $$
begin
  -- Valid platform values
  begin
    insert into public.waitlist_subscribers (email, platform) values ('test-plat@example.com', 'playstation');
    raise exception 'Should have rejected invalid platform';
  exception when check_violation then
    null; -- expected
  end;

  -- Valid locale values
  begin
    insert into public.waitlist_subscribers (email, locale) values ('test-loc@example.com', 'fr');
    raise exception 'Should have rejected invalid locale';
  exception when check_violation then
    null; -- expected
  end;

  -- Newly accepted desktop platform values should pass
  insert into public.waitlist_subscribers (email, platform, locale) values ('test-win@example.com', 'windows', 'ru');
  insert into public.waitlist_subscribers (email, platform, locale) values ('test-mac@example.com', 'macos', 'kk');
  insert into public.waitlist_subscribers (email, platform, locale) values ('test-linux@example.com', 'linux', 'ru');

  -- Valid campaign status
  begin
    insert into public.launch_campaigns (subject, body_html, status) values ('t', '<p>t</p>', 'deleted');
    raise exception 'Should have rejected invalid campaign status';
  exception when check_violation then
    null; -- expected
  end;

  -- Valid send status
  begin
    insert into public.launch_sends (campaign_id, subscriber_id, email, status)
      values (gen_random_uuid(), gen_random_uuid(), 'x@x.com', 'queued');
    raise exception 'Should have rejected invalid send status';
  exception when foreign_key_violation or check_violation then
    null; -- expected (might hit FK before check)
  end;

  raise notice 'PASS: check constraints enforce valid values';
end $$;

-- ============================================================
-- 4) Verify insert + unique constraint on email
-- ============================================================
do $$
declare
  sub_id uuid;
begin
  insert into public.waitlist_subscribers (email, platform, locale, timezone)
    values ('hello@sunnad.com', 'ios', 'en', 'Asia/Almaty')
    returning id into sub_id;

  assert sub_id is not null, 'Insert should return an ID';

  -- Duplicate email (case-insensitive) should fail
  begin
    insert into public.waitlist_subscribers (email, platform, locale) values ('Hello@sunnad.com', 'android', 'ru');
    raise exception 'Should have rejected duplicate email';
  exception when unique_violation then
    null; -- expected
  end;

  raise notice 'PASS: insert and unique email constraint work';
end $$;

-- ============================================================
-- 5) Verify campaign + send workflow
-- ============================================================
do $$
declare
  camp_id uuid;
  sub_id uuid;
  send_id uuid;
begin
  select id into sub_id from public.waitlist_subscribers where email = 'hello@sunnad.com';

  insert into public.launch_campaigns (subject, body_html, locale, status, total_recipients)
    values ('Sunnad is here!', '<h1>Welcome</h1>', 'en', 'draft', 1)
    returning id into camp_id;

  insert into public.launch_sends (campaign_id, subscriber_id, email, status)
    values (camp_id, sub_id, 'hello@sunnad.com', 'pending')
    returning id into send_id;

  assert send_id is not null, 'Send record should be created';

  -- Double-send prevention
  begin
    insert into public.launch_sends (campaign_id, subscriber_id, email, status)
      values (camp_id, sub_id, 'hello@sunnad.com', 'pending');
    raise exception 'Should have rejected duplicate send';
  exception when unique_violation then
    null; -- expected
  end;

  -- Update send status
  update public.launch_sends set status = 'sent', sent_at = now() where id = send_id;

  raise notice 'PASS: campaign send workflow works';
end $$;

-- ============================================================
-- 6) Verify helper function
-- ============================================================
do $$
declare
  r record;
begin
  select * into r from public.waitlist_subscriber_count_by_locale() where locale = 'en';
  assert r.active_count = 1, 'Should count 1 active EN subscriber';

  raise notice 'PASS: waitlist_subscriber_count_by_locale works';
end $$;

-- ============================================================
-- 7) Verify RLS blocks anon access
-- ============================================================
do $$
begin
  set local role anon;

  -- Anon should see zero rows (RLS blocks)
  assert (select count(*) from public.waitlist_subscribers) = 0,
    'Anon should see no waitlist rows';
  assert (select count(*) from public.launch_campaigns) = 0,
    'Anon should see no campaign rows';
  assert (select count(*) from public.launch_sends) = 0,
    'Anon should see no send rows';

  raise notice 'PASS: anon user blocked by RLS';

  -- Reset role
  set local role postgres;
end $$;

do $$
begin
  raise notice '=== ALL STAGE 10 SMOKE TESTS PASSED ===';
end $$;

rollback;
