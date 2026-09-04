-- Adat 1.1: native Apple Push Notification service delivery.

alter table public.device_tokens
  add column if not exists apns_environment text not null default 'production';

alter table public.device_tokens
  drop constraint if exists device_tokens_apns_environment_check;

alter table public.device_tokens
  add constraint device_tokens_apns_environment_check
  check (apns_environment in ('development', 'production'));

comment on column public.device_tokens.apns_environment is
  'APNs endpoint associated with the token: development (sandbox) or production.';

