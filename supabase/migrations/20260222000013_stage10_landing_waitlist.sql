-- Sunnad — Migration 13: Stage 10 landing waitlist and launch campaigns
-- Tables: waitlist_subscribers, launch_campaigns, launch_sends

-- ============================================================
-- 1) waitlist_subscribers — email waitlist signups
-- ============================================================
create table if not exists public.waitlist_subscribers (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  platform text not null default 'unknown'
    constraint waitlist_subscribers_platform_check
    check (platform in ('ios', 'android', 'both', 'unknown')),
  locale text not null default 'en'
    constraint waitlist_subscribers_locale_check
    check (locale in ('en', 'ru', 'kk')),
  variant text
    constraint waitlist_subscribers_variant_check
    check (variant is null or variant in ('1', '2', '3', '4', '5')),
  timezone text,
  referral_source text,
  ip_hash text,            -- sha256 of IP, used for rate-limiting; never store raw IPs
  subscribed_at timestamptz not null default now(),
  unsubscribed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- One subscription per email (upsert target)
create unique index if not exists waitlist_subscribers_email_uniq
  on public.waitlist_subscribers (lower(email));

-- Fast lookups for campaign sends
create index if not exists waitlist_subscribers_active_idx
  on public.waitlist_subscribers (subscribed_at)
  where unsubscribed_at is null;

-- Rate-limit lookup by ip_hash within a time window
create index if not exists waitlist_subscribers_ip_hash_idx
  on public.waitlist_subscribers (ip_hash, created_at);

-- Updated-at trigger
create trigger set_waitlist_subscribers_updated_at
  before update on public.waitlist_subscribers
  for each row execute function public.set_updated_at();

-- ============================================================
-- 2) launch_campaigns — manual launch email campaigns
-- ============================================================
create table if not exists public.launch_campaigns (
  id uuid primary key default gen_random_uuid(),
  subject text not null,
  body_html text not null,
  body_text text,           -- plain-text fallback
  locale text not null default 'en'
    constraint launch_campaigns_locale_check
    check (locale in ('en', 'ru', 'kk')),
  status text not null default 'draft'
    constraint launch_campaigns_status_check
    check (status in ('draft', 'sending', 'sent', 'failed')),
  total_recipients int not null default 0,
  total_sent int not null default 0,
  total_failed int not null default 0,
  started_at timestamptz,
  completed_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists launch_campaigns_status_idx
  on public.launch_campaigns (status);

create trigger set_launch_campaigns_updated_at
  before update on public.launch_campaigns
  for each row execute function public.set_updated_at();

-- ============================================================
-- 3) launch_sends — per-recipient delivery log
-- ============================================================
create table if not exists public.launch_sends (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.launch_campaigns(id) on delete cascade,
  subscriber_id uuid not null references public.waitlist_subscribers(id) on delete cascade,
  email text not null,
  status text not null default 'pending'
    constraint launch_sends_status_check
    check (status in ('pending', 'sent', 'failed', 'bounced')),
  resend_message_id text,    -- Resend API message ID for tracking
  error_message text,
  sent_at timestamptz,
  created_at timestamptz not null default now()
);

-- Prevent double-sends in the same campaign
create unique index if not exists launch_sends_campaign_subscriber_uniq
  on public.launch_sends (campaign_id, subscriber_id);

-- Fast lookup for campaign progress
create index if not exists launch_sends_campaign_status_idx
  on public.launch_sends (campaign_id, status);

-- ============================================================
-- 4) RLS policies
-- ============================================================

-- Enable RLS on all three tables
alter table public.waitlist_subscribers enable row level security;
alter table public.launch_campaigns enable row level security;
alter table public.launch_sends enable row level security;

-- waitlist_subscribers: service-role only writes (via edge function);
-- admins can read for campaign management
create policy "admins_read_waitlist"
  on public.waitlist_subscribers
  for select
  to authenticated
  using (public.is_allowlisted_admin());

-- No direct insert/update/delete from authenticated users (service-role only)

-- launch_campaigns: admin CRUD
create policy "admins_manage_campaigns"
  on public.launch_campaigns
  for all
  to authenticated
  using (public.is_allowlisted_admin())
  with check (public.is_allowlisted_admin());

-- launch_sends: admin read, service-role inserts
create policy "admins_read_sends"
  on public.launch_sends
  for select
  to authenticated
  using (public.is_allowlisted_admin());

-- ============================================================
-- 5) Helper: count active subscribers by locale
-- ============================================================
create or replace function public.waitlist_subscriber_count_by_locale()
returns table(locale text, active_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  select
    ws.locale,
    count(*) as active_count
  from public.waitlist_subscribers ws
  where ws.unsubscribed_at is null
  group by ws.locale;
$$;

-- Grant execute to authenticated (admins will pass RLS on underlying calls)
grant execute on function public.waitlist_subscriber_count_by_locale() to authenticated;
