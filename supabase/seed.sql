-- ============================================================
-- Sunnad - Seed Data
-- ============================================================

-- Create quote sets first (one per thematic group for multilingual quotes)
-- Using deterministic UUIDs so we can reference them below.
insert into public.quote_sets (id, status, created_at, updated_at) values
  ('00000000-0000-4000-a000-000000000001', 'approved', now(), now()),
  ('00000000-0000-4000-a000-000000000002', 'approved', now(), now()),
  ('00000000-0000-4000-a000-000000000003', 'approved', now(), now()),
  ('00000000-0000-4000-a000-000000000004', 'approved', now(), now()),
  ('00000000-0000-4000-a000-000000000005', 'approved', now(), now()),
  ('00000000-0000-4000-a000-000000000006', 'approved', now(), now()),
  ('00000000-0000-4000-a000-000000000007', 'approved', now(), now()),
  ('00000000-0000-4000-a000-000000000008', 'approved', now(), now()),
  ('00000000-0000-4000-a000-000000000009', 'approved', now(), now()),
  ('00000000-0000-4000-a000-00000000000a', 'approved', now(), now());

-- Sample quotes (English) — mapped to quote sets
insert into public.quotes (quote_set_id, locale, text, source, draft) values
  ('00000000-0000-4000-a000-000000000001', 'en', 'The best of deeds are those done consistently, even if small.', 'Prophet Muhammad ﷺ (Bukhari & Muslim)', false),
  ('00000000-0000-4000-a000-000000000002', 'en', 'Verily, with hardship comes ease.', 'Quran 94:6', false),
  ('00000000-0000-4000-a000-000000000003', 'en', 'Take advantage of five before five: your youth before your old age, your health before your illness, your wealth before your poverty, your free time before your busyness, and your life before your death.', 'Prophet Muhammad ﷺ (Hakim)', false),
  ('00000000-0000-4000-a000-000000000004', 'en', 'Whoever treads a path seeking knowledge, Allah will make easy for him a path to Paradise.', 'Prophet Muhammad ﷺ (Muslim)', false),
  ('00000000-0000-4000-a000-000000000005', 'en', 'The strong believer is better and more beloved to Allah than the weak believer, while there is good in both.', 'Prophet Muhammad ﷺ (Muslim)', false),
  ('00000000-0000-4000-a000-000000000006', 'en', 'Indeed, Allah does not change the condition of a people until they change what is in themselves.', 'Quran 13:11', false),
  ('00000000-0000-4000-a000-000000000007', 'en', 'Be in this world as if you were a stranger or a traveler along a path.', 'Prophet Muhammad ﷺ (Bukhari)', false),
  ('00000000-0000-4000-a000-000000000008', 'en', 'And whoever relies upon Allah - then He is sufficient for him.', 'Quran 65:3', false),
  ('00000000-0000-4000-a000-000000000009', 'en', 'The most beloved of deeds to Allah are the most consistent of them, even if they are few.', 'Prophet Muhammad ﷺ (Bukhari)', false),
  ('00000000-0000-4000-a000-00000000000a', 'en', 'So remember Me; I will remember you.', 'Quran 2:152', false);

-- Sample quotes (Russian) — mapped to matching quote sets
insert into public.quotes (quote_set_id, locale, text, source, draft) values
  ('00000000-0000-4000-a000-000000000001', 'ru', 'Лучшие из дел - те, что совершаются постоянно, даже если они малы.', 'Пророк Мухаммад ﷺ (Бухари и Муслим)', false),
  ('00000000-0000-4000-a000-000000000002', 'ru', 'Поистине, за тягостью - облегчение.', 'Коран 94:6', false),
  ('00000000-0000-4000-a000-00000000000a', 'ru', 'Поминайте Меня, и Я буду помнить о вас.', 'Коран 2:152', false),
  ('00000000-0000-4000-a000-000000000008', 'ru', 'На Аллаха уповающему - достаточно Его.', 'Коран 65:3', false),
  ('00000000-0000-4000-a000-000000000006', 'ru', 'Аллах не меняет положения людей, пока они не изменят самих себя.', 'Коран 13:11', false);

-- Sample quotes (Kazakh) — mapped to matching quote sets
insert into public.quotes (quote_set_id, locale, text, source, draft) values
  ('00000000-0000-4000-a000-000000000001', 'kk', 'Ең жақсы амалдар - аз болса да, тұрақты жасалатындар.', 'Мұхаммад Пайғамбар ﷺ (Бұхари және Мүслім)', false),
  ('00000000-0000-4000-a000-000000000002', 'kk', 'Қиыншылықпен бірге жеңілдік бар.', 'Құран 94:6', false),
  ('00000000-0000-4000-a000-00000000000a', 'kk', 'Мені еске алыңдар, Мен де сендерді еске аламын.', 'Құран 2:152', false),
  ('00000000-0000-4000-a000-000000000008', 'kk', 'Аллаһқа тәуекел еткенге - Ол жеткілікті.', 'Құран 65:3', false),
  ('00000000-0000-4000-a000-000000000006', 'kk', 'Аллаһ бір елдің жағдайын өзгертпейді, олар өздерін өзгертпейінше.', 'Құран 13:11', false);

-- Admin allowlist seed (for local dev & initial production bootstrapping)
insert into public.admin_allowlist (email, role) values
  ('alimkhan.ergebayev@gmail.com', 'owner')
on conflict (email) do nothing;
