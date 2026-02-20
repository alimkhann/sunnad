-- ============================================================
-- Sunnad — Migration 8: Profile avatar + username hardening
-- ============================================================

-- Add profile avatar reference for storage path (or oauth avatar URL fallback).
alter table public.profiles
  add column if not exists avatar_path text;

-- Normalize existing usernames to lowercase/underscore format where possible.
with normalized as (
  select
    p.id,
    nullif(left(trim(both '_' from regexp_replace(lower(coalesce(p.username, '')), '[^a-z0-9_]+', '_', 'g')), 20), '') as normalized_username,
    row_number() over (
      partition by nullif(left(trim(both '_' from regexp_replace(lower(coalesce(p.username, '')), '[^a-z0-9_]+', '_', 'g')), 20), '')
      order by p.created_at, p.id
    ) as rn
  from public.profiles p
  where p.username is not null
), prepared as (
  select
    id,
    case
      when normalized_username is null then null
      when length(normalized_username) < 3 then null
      when rn > 1 then null
      else normalized_username
    end as final_username
  from normalized
)
update public.profiles p
set username = prepared.final_username
from prepared
where p.id = prepared.id;

alter table public.profiles
  drop constraint if exists profiles_username_format_check;

alter table public.profiles
  add constraint profiles_username_format_check
  check (username is null or username ~ '^[a-z0-9_]{3,20}$');

-- Collision-safe oauth username claimer for first login defaults.
create or replace function public.claim_oauth_username(base text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_base text;
  v_candidate text;
  v_suffix int := 0;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  v_base := lower(trim(coalesce(base, '')));
  v_base := regexp_replace(v_base, '[^a-z0-9_]+', '_', 'g');
  v_base := trim(both '_' from v_base);

  if v_base = '' then
    v_base := 'user';
  end if;

  if length(v_base) < 3 then
    v_base := rpad(v_base, 3, '0');
  end if;

  v_base := left(v_base, 20);

  loop
    if v_suffix = 0 then
      v_candidate := v_base;
    else
      v_candidate := left(v_base, greatest(1, 20 - length(v_suffix::text) - 1)) || '_' || v_suffix::text;
    end if;

    exit when not exists (
      select 1
      from public.profiles p
      where p.id <> v_user_id
        and lower(p.username) = lower(v_candidate)
    );

    v_suffix := v_suffix + 1;

    if v_suffix > 9999 then
      raise exception 'Unable to claim username';
    end if;
  end loop;

  update public.profiles
  set username = v_candidate
  where id = v_user_id;

  return v_candidate;
end;
$$;

revoke all on function public.claim_oauth_username(text) from public;
grant execute on function public.claim_oauth_username(text) to authenticated;

-- Public avatar bucket with ownership policies.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can read avatar objects" on storage.objects;
create policy "Public can read avatar objects"
  on storage.objects for select
  using (bucket_id = 'avatars');

drop policy if exists "Users can upload own avatar objects" on storage.objects;
create policy "Users can upload own avatar objects"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = 'profiles'
    and (storage.foldername(name))[2] = auth.uid()::text
  );

drop policy if exists "Users can update own avatar objects" on storage.objects;
create policy "Users can update own avatar objects"
  on storage.objects for update
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = 'profiles'
    and (storage.foldername(name))[2] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = 'profiles'
    and (storage.foldername(name))[2] = auth.uid()::text
  );

drop policy if exists "Users can delete own avatar objects" on storage.objects;
create policy "Users can delete own avatar objects"
  on storage.objects for delete
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = 'profiles'
    and (storage.foldername(name))[2] = auth.uid()::text
  );
