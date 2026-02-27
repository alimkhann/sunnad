-- Sunnad — Migration 17: Remove waitlist variant and normalize platform taxonomy

-- Drop stale variant tracking from waitlist subscribers.
alter table public.waitlist_subscribers
  drop constraint if exists waitlist_subscribers_variant_check;

alter table public.waitlist_subscribers
  drop column if exists variant;

-- Expand platform taxonomy for better desktop attribution.
update public.waitlist_subscribers
set platform = 'unknown'
where platform not in ('ios', 'android', 'macos', 'windows', 'linux', 'unknown');

alter table public.waitlist_subscribers
  drop constraint if exists waitlist_subscribers_platform_check;

alter table public.waitlist_subscribers
  add constraint waitlist_subscribers_platform_check
  check (platform in ('ios', 'android', 'macos', 'windows', 'linux', 'unknown'));
