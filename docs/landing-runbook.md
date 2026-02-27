# Landing Page — Deployment & Operations Runbook

## Overview

The Sunnad landing page is a Next.js app located in `/landing/`. It supports 3 locales (EN/RU/KK), a waitlist signup with Cloudflare Turnstile, and a manual launch email system via Resend.

---

## Environment Variables

### Landing App (`landing/.env.local`)

| Variable                         | Description                          | Required |
| -------------------------------- | ------------------------------------ | -------- |
| `NEXT_PUBLIC_SUPABASE_URL`       | Supabase project URL                 | Yes      |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY`  | Supabase anon/public key             | Yes      |
| `NEXT_PUBLIC_TURNSTILE_SITE_KEY` | Cloudflare Turnstile site key        | Yes      |

### Edge Functions (Supabase Secrets)

| Secret                 | Used By           | Description                              |
| ---------------------- | ----------------- | ---------------------------------------- |
| `TURNSTILE_SECRET_KEY` | `waitlist-submit` | Cloudflare Turnstile server-side secret  |
| `RESEND_API_KEY`       | `launch-send`     | Resend API key for sending launch emails |
| `RESEND_FROM_EMAIL`    | `launch-send`     | Verified sender email address            |

Set secrets via:

```bash
supabase secrets set TURNSTILE_SECRET_KEY=0x4AAA...
supabase secrets set RESEND_API_KEY=re_Zoob...
supabase secrets set RESEND_FROM_EMAIL=you@example.com
```

---

## Deployment

### Landing App (Vercel)

1. Connect the repo to Vercel.
2. Set root directory to `landing/`.
3. Framework preset: Next.js.
4. Add all `NEXT_PUBLIC_*` env vars in Vercel dashboard.
5. Deploy. The app builds with `npm run build` (port 3001 in dev, standard in prod).

### Database Migration

The waitlist schema is in `supabase/migrations/20260222000013_stage10_landing_waitlist.sql`.

```bash
# Apply to linked remote project
supabase db push

# Or reset local stack (destructive)
supabase db reset
```

Tables created:

- `waitlist_subscribers` — email signups with platform/locale tracking
- `launch_campaigns` — email campaign drafts and send status
- `launch_sends` — per-recipient send tracking with Resend message IDs

### Edge Functions

Deploy both functions:

```bash
supabase functions deploy waitlist-submit --no-verify-jwt
supabase functions deploy launch-send
```

Note: `waitlist-submit` uses `--no-verify-jwt` because it's called from anonymous visitors. `launch-send` requires admin auth (service-role or admin user JWT).

---

## Cloudflare Turnstile Setup

1. Go to [Cloudflare Dashboard → Turnstile](https://dash.cloudflare.com/?to=/:account/turnstile).
2. Add a site with the landing page domain(s).
3. Choose "Managed" challenge mode.
4. Copy the **Site Key** → `NEXT_PUBLIC_TURNSTILE_SITE_KEY`.
5. Copy the **Secret Key** → Supabase secret `TURNSTILE_SECRET_KEY`.

The widget renders as a visible checkbox in the waitlist form — do NOT use invisible mode.

---

## Resend Email Setup

1. Sign up at [resend.com](https://resend.com).
2. Verify the sender domain or use a verified sender email.
3. Create an API key with "Send" permission.
4. Set `RESEND_API_KEY` and `RESEND_FROM_EMAIL` as Supabase secrets.

### Rate Limits

- Resend free tier: 100 emails/day, 1 email/second.
- The `launch-send` function adds a 1.1s delay between sends.
- For large subscriber lists, consider upgrading the Resend plan.

---

## Sending a Launch Email

Launch emails are sent manually via the `launch-send` edge function.

### 1. Create a campaign

```bash
curl -X POST "$SUPABASE_URL/functions/v1/launch-send/campaigns" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "subject_en": "Sunnad is live!",
    "body_html": "<h1>Welcome</h1><p>Download now...</p>",
    "body_text": "Welcome! Download now...",
    "locale_filter": "en"
  }'
```

### 2. Review the campaign

```bash
curl "$SUPABASE_URL/functions/v1/launch-send/campaigns/$CAMPAIGN_ID" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY"
```

### 3. Send

```bash
curl -X POST "$SUPABASE_URL/functions/v1/launch-send/campaigns/$CAMPAIGN_ID/send" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY"
```

The function will:

- Set campaign status to `sending`
- Enqueue sends for all active subscribers matching the locale filter
- Send emails sequentially with rate limiting
- Track success/failure per recipient
- Update campaign status to `sent` or `failed`

---

## Monitoring

### Waitlist Stats

```sql
-- Total subscribers by locale
SELECT * FROM waitlist_subscriber_count_by_locale();

-- Recent signups
SELECT email, locale, platform, subscribed_at
FROM waitlist_subscribers
WHERE unsubscribed_at IS NULL
ORDER BY subscribed_at DESC
LIMIT 20;
```

### Campaign Status

```sql
SELECT id, subject_en, status, total_count, sent_count, failed_count, sent_at
FROM launch_campaigns
ORDER BY created_at DESC;
```

### Failed Sends

```sql
SELECT ls.email, ls.status, ls.error_message, lc.subject_en
FROM launch_sends ls
JOIN launch_campaigns lc ON lc.id = ls.campaign_id
WHERE ls.status = 'failed';
```

---

## Abuse Controls

### Waitlist Submission

- **Turnstile verification**: every submission verified server-side
- **IP rate limiting**: max 5 submissions per IP per hour (SHA-256 hashed)
- **Email normalization**: lowercased per RFC 5321
- **Duplicate handling**: upserts — re-subscribing an unsubscribed email reactivates it

### Launch Sending

- **Admin-only**: requires service-role key or admin JWT
- **One-shot sends**: campaign goes `draft → sending → sent`, no re-sends
- **Per-recipient tracking**: each send logged with Resend message ID

---

## Troubleshooting

| Issue                           | Check                                                                                 |
| ------------------------------- | ------------------------------------------------------------------------------------- |
| Turnstile widget not loading    | Verify `NEXT_PUBLIC_TURNSTILE_SITE_KEY` is set and domain is registered in Cloudflare |
| "Verification failed" on submit | Check `TURNSTILE_SECRET_KEY` is correct in Supabase secrets                           |
| "Rate limited" on submit        | IP has hit 5 submissions/hour — wait or test from different IP                        |
| Launch emails not sending       | Verify `RESEND_API_KEY` and `RESEND_FROM_EMAIL`; check Resend dashboard for bounces   |
| Build fails in CI               | Ensure placeholder env vars are set (CI uses dummy values for build check)            |
