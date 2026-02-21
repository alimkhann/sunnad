-- ============================================================
-- Sunnad — Migration 5: Username Sign-In + Profile Username Sync
-- ============================================================

-- Keep profile username in sync at signup from auth metadata.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
declare
  v_username text := nullif(trim(new.raw_user_meta_data ->> 'username'), '');
begin
  insert into public.profiles (id, username)
  values (new.id, v_username);
  return new;
end;
$$;

-- Enforce case-insensitive uniqueness for usernames.
create unique index if not exists profiles_username_lower_uidx
  on public.profiles (lower(username))
  where username is not null;

-- Backfill usernames for existing users where possible.
with candidates as (
  select
    p.id,
    nullif(trim(u.raw_user_meta_data ->> 'username'), '') as username,
    row_number() over (
      partition by lower(nullif(trim(u.raw_user_meta_data ->> 'username'), ''))
      order by u.created_at asc
    ) as rn
  from public.profiles p
  join auth.users u
    on u.id = p.id
  where (p.username is null or p.username = '')
    and nullif(trim(u.raw_user_meta_data ->> 'username'), '') is not null
)
update public.profiles p
set username = c.username
from candidates c
where p.id = c.id
  and c.rn = 1
  and not exists (
    select 1
    from public.profiles p2
    where p2.id <> p.id
      and lower(p2.username) = lower(c.username)
  );

-- Allow sign-in by username on the client by resolving to email.
create or replace function public.resolve_sign_in_email(identifier text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_input text := lower(trim(identifier));
  v_email text;
begin
  if v_input is null or v_input = '' then
    return null;
  end if;

  if position('@' in v_input) > 0 then
    return v_input;
  end if;

  select u.email
    into v_email
  from public.profiles p
  join auth.users u
    on u.id = p.id
  where lower(p.username) = v_input
  limit 1;

  return coalesce(v_email, v_input);
end;
$$;

revoke all on function public.resolve_sign_in_email(text) from public;
grant execute on function public.resolve_sign_in_email(text) to anon, authenticated;
