# Supabase Environments (No-Pro Workflow)

## Environments
- `local`: daily development with Supabase CLI (`supabase start`).
- `sunnad-dev`: hosted free project for integration testing.
- `sunnad-prod`: hosted free project for production data.

## Branching policy
- Do not rely on paid hosted preview branches for routine workflow.
- Validate schema locally first, then promote to dev, then prod.

## Schema promotion flow
1. Create migration SQL in `supabase/migrations/`.
2. Verify from scratch locally:
   - `supabase db reset`
   - `psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/stage4_smoke.sql`
3. Push to dev project and smoke test.
4. Push the same migration set to prod.
5. Record migration release notes and backup artifacts.

## Data safety rules
- Never commit secrets or service keys.
- Keep RLS as the authorization layer.
- All schema changes are migration-driven.

## Stage-4 contract checklist
- Group create path uses `public.create_group_with_owner(...)`.
- Group join by invite code is case-insensitive and trimmed.
- `habits.schedule` accepts only `daily|weekly`.
- Ownership FKs are in place for completions/shared-habits to habits.
- `group_members` and `saved_quotes` include `updated_at` for sync windows.

## CI/CD workflow (free tier)
- Pull request CI:
  - `.github/workflows/ci.yml`
  - Runs `supabase db reset` + Stage-4 smoke SQL checks.
  - Runs iOS `xcodebuild test` on `sunnad-ios` scheme.
- Manual deployment:
  - `.github/workflows/cd-manual.yml` (`workflow_dispatch` only).
  - Supports `dev` or `prod` target environment.
  - Pushes DB migrations and optionally deploys edge functions.

## GitHub environment secrets
Create `dev` and `prod` GitHub environments with:
- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_DB_URL`
- `SUPABASE_PROJECT_REF`

## iOS Xcode env vars (Run/Test scheme)
Set these in `Edit Scheme` -> `Run` -> `Arguments` -> `Environment Variables`.

### Local Supabase
- `SUNNAD_SUPABASE_URL=http://127.0.0.1:55421`
- `SUNNAD_SUPABASE_ANON_KEY=<local publishable/anon key from supabase start>`
- `SUNNAD_AUTH_REDIRECT_URL=sunnad://auth-callback`
- `SUNNAD_AUTH_GOOGLE_ENABLED=1`
- `SUNNAD_AUTH_APPLE_ENABLED=0`
- `SUNNAD_DISABLE_LOCAL_SUPABASE_FALLBACK=1`

### Hosted dev project
- `SUNNAD_SUPABASE_URL=https://wejnrzlxnesqhbtvgdga.supabase.co`
- `SUNNAD_SUPABASE_ANON_KEY=<sunnad-dev anon/publishable key>`
- `SUNNAD_AUTH_REDIRECT_URL=sunnad://auth-callback`
- `SUNNAD_AUTH_GOOGLE_ENABLED=1`
- `SUNNAD_AUTH_APPLE_ENABLED=0`
- `SUNNAD_DISABLE_LOCAL_SUPABASE_FALLBACK=1`

### Hosted prod project
- `SUNNAD_SUPABASE_URL=https://artwfvypcdacdpqhciqt.supabase.co`
- `SUNNAD_SUPABASE_ANON_KEY=<sunnad-prod anon/publishable key>`
- `SUNNAD_AUTH_REDIRECT_URL=sunnad://auth-callback`
- `SUNNAD_AUTH_GOOGLE_ENABLED=1`
- `SUNNAD_AUTH_APPLE_ENABLED=0`
- `SUNNAD_DISABLE_LOCAL_SUPABASE_FALLBACK=1`

Notes:
- `SUNNAD_SUPABASE_PUBLISHABLE_KEY` is also supported; `SUNNAD_SUPABASE_ANON_KEY` is preferred in app setup.
- Do not wrap values in quotes in Xcode env rows.
- Keep `SUNNAD_DISABLE_LOCAL_SUPABASE_FALLBACK=1` enabled when validating a specific env so missing/wrong keys fail fast.

## Auth settings required for OTP/recovery (all envs)
- Auth -> Sign In / Providers:
  - `Allow new users to sign up`: enabled
  - `Confirm email`: enabled
- Auth -> URL Configuration:
  - Add redirect URL: `sunnad://auth-callback`
- Recovery and signup confirmations now use `sunnad://auth-callback` so no web domain is required for mobile auth flows.

## Email template parity checklist (local/dev/prod)
Use the same content in local template files and hosted dashboard templates:
- Confirmation email includes:
  - `{{ .ConfirmationURL }}`
  - `{{ .Token }}`
- Recovery email includes:
  - `{{ .ConfirmationURL }}`
  - `{{ .Token }}`

Local source-of-truth files:
- `supabase/templates/auth/confirmation.html`
- `supabase/templates/auth/recovery.html`

Local CLI config references:
- `supabase/config.toml`:
  - `[auth.email.template.confirmation]`
  - `[auth.email.template.recovery]`

Hosted dev/prod parity steps:
1. Open Supabase Dashboard -> Auth -> Email Templates.
2. Update `Confirm signup` with confirmation template content.
3. Update `Reset password` with recovery template content.
4. Save in both `sunnad-dev` and `sunnad-prod`.

## OAuth provider checklist
- Google (enabled now):
  - Auth -> Sign In / Providers -> Google: enabled.
  - Use provider credentials from Google Cloud OAuth app.
  - Callback URL in Google console:
    - `https://<project-ref>.supabase.co/auth/v1/callback`
- Apple (prewired only):
  - Keep disabled until Apple Developer credentials are ready.
  - App shows Apple button disabled via `SUNNAD_AUTH_APPLE_ENABLED=0`.

## Local email testing (Mailpit)
- Supabase local runs Mailpit at `http://127.0.0.1:54324`.
- Inbox UI: open `http://127.0.0.1:54324`.
- API: `http://127.0.0.1:54324/api/v1/messages`.
- Helper script:
  - `scripts/dev/mailpit_latest_auth.sh any`
  - `scripts/dev/mailpit_latest_auth.sh confirm`
  - `scripts/dev/mailpit_latest_auth.sh reset`
- Open latest confirmation/reset link directly in booted simulator (recommended):
  - `scripts/dev/mailpit_open_latest_link_sim.sh confirm`
  - `scripts/dev/mailpit_open_latest_link_sim.sh reset`
- The helper prints recipient, subject, extracted `sunnad://auth-callback...` deep link, and OTP code (if present).
- Recovery flow supports both:
  - link-first: open reset link in simulator Safari -> app opens Change Password flow.
  - code-first: copy OTP code and verify in app recovery OTP screen.
