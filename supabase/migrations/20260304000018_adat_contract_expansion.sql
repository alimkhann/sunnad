-- ============================================================
-- Adat — Migration 18: Habit category/icon contracts + group progress mode
-- ============================================================

-- ------------------------------------------------------------
-- 1) Habits: canonical icon + category metadata
-- ------------------------------------------------------------
alter table public.habits
  add column if not exists icon_key text,
  add column if not exists preset_category text,
  add column if not exists category_custom text;

alter table public.habits
  alter column preset_category set default 'spiritual';

-- Keep preset categories constrained while allowing nullable custom labels.
alter table public.habits
  drop constraint if exists habits_preset_category_check;

alter table public.habits
  add constraint habits_preset_category_check
  check (
    preset_category is null
    or preset_category in (
      'spiritual',
      'physical',
      'social',
      'financial',
      'learning',
      'family',
      'work',
      'hobby'
    )
  );

update public.habits
set icon_key = case
  when icon_key is not null and btrim(icon_key) <> '' then icon_key
  when icon is null then 'star.fill'
  when lower(icon) in ('sun', 'sunrise', 'sunrise.fill', 'sun.max.fill', 'wb_sunny', 'wbsunny') then 'sunrise.fill'
  when lower(icon) in ('moon', 'moon.fill', 'moon.stars.fill', 'bedtime') then 'moon.fill'
  when lower(icon) in ('book', 'book.fill', 'book.closed.fill', 'menu_book') then 'book.closed.fill'
  when lower(icon) in ('run', 'figure.run', 'fitness_center', 'runner') then 'figure.run'
  when lower(icon) in ('group', 'groups', 'person.2.fill', 'person.3.fill', 'person.2') then 'person.2.fill'
  when lower(icon) in ('money', 'banknote.fill', 'creditcard.fill', 'credit', 'monetization_on') then 'banknote.fill'
  when lower(icon) in ('heart', 'heart.fill', 'favorite') then 'heart.fill'
  when lower(icon) in ('dhikr', 'sparkles', 'spa', 'self_improvement') then 'sparkles'
  when lower(icon) in ('star', 'star.fill') then 'star.fill'
  else coalesce(nullif(icon, ''), 'star.fill')
end;

update public.habits
set preset_category = coalesce(nullif(lower(preset_category), ''), 'spiritual')
where preset_category is null
   or btrim(preset_category) = '';

create index if not exists habits_user_preset_category_idx
  on public.habits (user_id, preset_category);

create index if not exists habits_icon_key_idx
  on public.habits (icon_key);

-- ------------------------------------------------------------
-- 2) Group members: per-member progress display preference
-- ------------------------------------------------------------
alter table public.group_members
  add column if not exists progress_display_mode text not null default 'percent';

alter table public.group_members
  drop constraint if exists group_members_progress_display_mode_check;

alter table public.group_members
  add constraint group_members_progress_display_mode_check
  check (progress_display_mode in ('percent', 'streak'));

create or replace function public.set_group_progress_display_mode(
  p_group_id uuid,
  p_mode text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_mode text := lower(trim(coalesce(p_mode, '')));
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if v_mode not in ('percent', 'streak') then
    raise exception 'Invalid progress display mode';
  end if;

  update public.group_members
  set progress_display_mode = v_mode,
      updated_at = now()
  where group_id = p_group_id
    and user_id = v_user_id;

  if not found then
    raise exception 'Forbidden';
  end if;
end;
$$;

revoke all on function public.set_group_progress_display_mode(uuid, text) from public;
grant execute on function public.set_group_progress_display_mode(uuid, text) to authenticated;
