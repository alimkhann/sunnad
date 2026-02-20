-- ============================================================
-- Sunnad — Migration 7: Ensure username sign-in resolver exists
-- ============================================================

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
