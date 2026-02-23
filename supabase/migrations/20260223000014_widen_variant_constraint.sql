-- Sunnad — Migration 14: Widen variant constraint for waitlist_subscribers
-- The original constraint only allowed variants '1'..'5'. Since we now use variant '14'
-- (and may add more in the future), we allow any 1-2 digit numeric string.

ALTER TABLE public.waitlist_subscribers
  DROP CONSTRAINT IF EXISTS waitlist_subscribers_variant_check;

ALTER TABLE public.waitlist_subscribers
  ADD CONSTRAINT waitlist_subscribers_variant_check
  CHECK (variant IS NULL OR variant ~ '^[0-9]{1,2}$');
