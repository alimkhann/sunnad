-- ============================================================
-- Sunnad - Seed Data
-- ============================================================

-- Sample quotes (English)
insert into public.quotes (locale, text, source) values
  ('en', 'The best of deeds are those done consistently, even if small.', 'Prophet Muhammad ﷺ (Bukhari & Muslim)'),
  ('en', 'Verily, with hardship comes ease.', 'Quran 94:6'),
  ('en', 'Take advantage of five before five: your youth before your old age, your health before your illness, your wealth before your poverty, your free time before your busyness, and your life before your death.', 'Prophet Muhammad ﷺ (Hakim)'),
  ('en', 'Whoever treads a path seeking knowledge, Allah will make easy for him a path to Paradise.', 'Prophet Muhammad ﷺ (Muslim)'),
  ('en', 'The strong believer is better and more beloved to Allah than the weak believer, while there is good in both.', 'Prophet Muhammad ﷺ (Muslim)'),
  ('en', 'Indeed, Allah does not change the condition of a people until they change what is in themselves.', 'Quran 13:11'),
  ('en', 'Be in this world as if you were a stranger or a traveler along a path.', 'Prophet Muhammad ﷺ (Bukhari)'),
  ('en', 'And whoever relies upon Allah - then He is sufficient for him.', 'Quran 65:3'),
  ('en', 'The most beloved of deeds to Allah are the most consistent of them, even if they are few.', 'Prophet Muhammad ﷺ (Bukhari)'),
  ('en', 'So remember Me; I will remember you.', 'Quran 2:152');

-- Sample quotes (Russian)
insert into public.quotes (locale, text, source) values
  ('ru', 'Лучшие из дел - те, что совершаются постоянно, даже если они малы.', 'Пророк Мухаммад ﷺ (Бухари и Муслим)'),
  ('ru', 'Поистине, за тягостью - облегчение.', 'Коран 94:6'),
  ('ru', 'Поминайте Меня, и Я буду помнить о вас.', 'Коран 2:152'),
  ('ru', 'На Аллаха уповающему - достаточно Его.', 'Коран 65:3'),
  ('ru', 'Аллах не меняет положения людей, пока они не изменят самих себя.', 'Коран 13:11');

-- Sample quotes (Kazakh)
insert into public.quotes (locale, text, source) values
  ('kk', 'Ең жақсы амалдар - аз болса да, тұрақты жасалатындар.', 'Мұхаммад Пайғамбар ﷺ (Бұхари және Мүслім)'),
  ('kk', 'Қиыншылықпен бірге жеңілдік бар.', 'Құран 94:6'),
  ('kk', 'Мені еске алыңдар, Мен де сендерді еске аламын.', 'Құран 2:152'),
  ('kk', 'Аллаһқа тәуекел еткенге - Ол жеткілікті.', 'Құран 65:3'),
  ('kk', 'Аллаһ бір елдің жағдайын өзгертпейді, олар өздерін өзгертпейінше.', 'Құран 13:11');
