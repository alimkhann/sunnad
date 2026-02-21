# Admin Quotes Runbook (EN/RU/KZ)

## Purpose
This admin panel lets allowlisted admins manage quote sets safely without using Supabase dashboard internals.

Core capabilities:
- create/edit/archive quote sets
- generate EN/RU drafts from Kazakh text via Gemini
- approve quote sets for publishing
- pin a quote set for a specific day (global)

Global quote-day behavior:
- one quote set per day for everyone
- day boundary uses `Asia/Almaty`

## Security model
All write operations go through Edge Functions:
- `admin-quotes`
- `translate-quote`

A user must satisfy both checks:
- `profiles.is_admin = true`
- user email is present in `public.admin_allowlist`

## Prerequisites
1. Add admin user in Supabase Auth.
2. Set `profiles.is_admin = true` for that user.
3. Add user email to `public.admin_allowlist`.
4. Deploy latest migrations and functions.
5. Configure admin web env vars:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`

## Operator setup checklist
1. Apply migration:
   - `supabase db push --db-url "$SUPABASE_DB_URL"`
2. Deploy functions:
   - `supabase functions deploy admin-quotes --project-ref <ref>`
   - `supabase functions deploy translate-quote --project-ref <ref>`
3. Set function secrets:
   - `supabase secrets set SUPABASE_SERVICE_ROLE_KEY=... --project-ref <ref>`
   - `supabase secrets set GEMINI_API_KEY=... --project-ref <ref>`
   - optional: `supabase secrets set GEMINI_MODEL=gemini-2.0-flash --project-ref <ref>`
4. Verify access by signing in to `/admin` with magic link.

## Editor workflow (non-technical)
1. Sign in with allowlisted email.
2. Click `New set`.
3. Fill Kazakh quote text first (required).
4. Optionally fill source.
5. Click `Generate EN/RU drafts`.
6. Review/edit EN/RU text.
7. Click `Create` (or `Save`).
8. Click `Approve` when ready for publication.
9. Optional: set a date and click `Pin day` to force this quote for that day.

## Troubleshooting
- `Forbidden` on login actions:
  - confirm both `is_admin=true` and allowlist row exist for same email.
- Translation fails:
  - verify `GEMINI_API_KEY` secret exists and is valid.
- Quote not visible in app:
  - ensure quote set is approved and translation row for target locale exists.
- Day pin not applied:
  - confirm date format `YYYY-MM-DD` and timezone expectation (`Asia/Almaty`).

## Translation quality policy
- Gemini output is draft-only.
- Human review is mandatory before approval.
- Preserve religious meaning and avoid loose paraphrasing.

## Advisor monitoring
For each deploy to dev/prod:
1. Run SQL lint checks in CI (`supabase/tests/advisor_lints.sql`).
2. Open Supabase Dashboard -> Security Advisor.
3. Record warning/info deltas in release notes.
4. Treat new warnings as blockers unless explicitly waived.
