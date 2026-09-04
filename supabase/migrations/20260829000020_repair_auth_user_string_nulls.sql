-- GoTrue scans these token fields as strings. Users created by an older manual
-- seed left them NULL, which makes every password and admin user query fail.
update auth.users
set
  recovery_token = coalesce(recovery_token, ''),
  email_change_token_new = coalesce(email_change_token_new, ''),
  email_change = coalesce(email_change, '')
where recovery_token is null
   or email_change_token_new is null
   or email_change is null;
