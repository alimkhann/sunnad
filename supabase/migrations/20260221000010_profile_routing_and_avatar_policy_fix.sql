-- ============================================================
-- Sunnad — Migration 10: Profile upsert helper + avatar policy fix
-- ============================================================

create or replace function public.upsert_profile_fields(
  p_username text default null,
  p_avatar_path text default null,
  p_set_username boolean default false,
  p_set_avatar boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.profiles (id)
  values (v_user_id)
  on conflict (id) do nothing;

  if p_set_username and p_set_avatar then
    update public.profiles
    set username = p_username,
        avatar_path = p_avatar_path
    where id = v_user_id;
  elsif p_set_username then
    update public.profiles
    set username = p_username
    where id = v_user_id;
  elsif p_set_avatar then
    update public.profiles
    set avatar_path = p_avatar_path
    where id = v_user_id;
  end if;
end;
$$;

revoke all on function public.upsert_profile_fields(text, text, boolean, boolean) from public;
grant execute on function public.upsert_profile_fields(text, text, boolean, boolean) to authenticated;

drop policy if exists "Users can upload own avatar objects" on storage.objects;
create policy "Users can upload own avatar objects"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars'
    and lower((storage.foldername(name))[1]) = 'profiles'
    and lower((storage.foldername(name))[2]) = lower(auth.uid()::text)
  );

drop policy if exists "Users can update own avatar objects" on storage.objects;
create policy "Users can update own avatar objects"
  on storage.objects for update
  using (
    bucket_id = 'avatars'
    and lower((storage.foldername(name))[1]) = 'profiles'
    and lower((storage.foldername(name))[2]) = lower(auth.uid()::text)
  )
  with check (
    bucket_id = 'avatars'
    and lower((storage.foldername(name))[1]) = 'profiles'
    and lower((storage.foldername(name))[2]) = lower(auth.uid()::text)
  );

drop policy if exists "Users can delete own avatar objects" on storage.objects;
create policy "Users can delete own avatar objects"
  on storage.objects for delete
  using (
    bucket_id = 'avatars'
    and lower((storage.foldername(name))[1]) = 'profiles'
    and lower((storage.foldername(name))[2]) = lower(auth.uid()::text)
  );
