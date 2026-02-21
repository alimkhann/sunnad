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

## Stage 6/7 parity gate (hosted)
Before testing remote Groups, ensure hosted projects include:
- `20260221000009_stage6_group_governance.sql`
- `20260221000010_profile_routing_and_avatar_policy_fix.sql`
- `20260221000011_advisor_rls_search_path_hardening.sql`

If `groups.join_locked` is missing remotely, Groups UI can still render via app fallback, but hosted migration parity is still required.

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
- `SUPABASE_FUNCTIONS_ONESIGNAL_APP_ID` (only if deploying `send-nudge-push`)
- `SUPABASE_FUNCTIONS_ONESIGNAL_REST_API_KEY` (only if deploying `send-nudge-push`)

## iOS runtime config model (build-time first, env second)
The app now reads Supabase/OAuth config from `Info.plist` bundle keys first.

Bundle keys:
- `SunnadSupabaseURL`
- `SunnadSupabaseAnonKey`
- `SunnadAuthRedirectURL`
- `SunnadAuthGoogleEnabled`
- `SunnadAuthAppleEnabled`
- `SunnadAuthResendCooldownSeconds`
- `SunnadStorageNamespace`

Debug-only environment overrides are supported for temporary troubleshooting:
- `SUNNAD_SUPABASE_URL`
- `SUNNAD_SUPABASE_ANON_KEY` (or `SUNNAD_SUPABASE_PUBLISHABLE_KEY`)
- `SUNNAD_AUTH_REDIRECT_URL`
- `SUNNAD_AUTH_GOOGLE_ENABLED`
- `SUNNAD_AUTH_APPLE_ENABLED`
- `SUNNAD_AUTH_RESEND_COOLDOWN_SECONDS`
- `SUNNAD_STORAGE_NAMESPACE`

Debug-only fallback flags:
- `SUNNAD_ENABLE_LOCAL_SUPABASE_FALLBACK=1` enables explicit local URL fallback.
- `SUNNAD_ALLOW_CACHED_SUPABASE_CONFIG=1` enables cached Supabase config fallback.
- Both are off by default.

## Xcode scheme -> build configuration mapping
- `sunnad-ios` (local): `Local`
- `sunnad-ios-dev`: `Debug`
- `sunnad-ios-prod`: `Release`

Configured app display names:
- local: `Sunnad Local`
- dev: `Sunnad Dev`
- prod: `Sunnad`

Configured bundle IDs:
- local: `com.arystan.almasuly.sunnad-ios.local`
- dev: `com.arystan.almasuly.sunnad-ios.dev`
- prod: `com.arystan.almasuly.sunnad-ios`

Configured Supabase endpoints:
- local (`Local`): `http://127.0.0.1:55421`
- dev (`Debug`): `https://wejnrzlxnesqhbtvgdga.supabase.co`
- prod (`Release`): `https://artwfvypcdacdpqhciqt.supabase.co`

Configured storage namespaces:
- local: `local`
- dev: `dev`
- prod: `prod`

In-app debug diagnostics (debug builds only) now show:
- `bundle id | supabase host | namespace`
- Use this on Profile screen to quickly confirm wrong-env launches.

## App Store note
- App Store builds use `Release` configuration, so Supabase values come from build settings embedded in `Info.plist`.
- No Xcode Run environment variables are available in App Store launch context.

## Reliability checks required per release candidate
1. Launch from Xcode and from installed icon for each environment scheme.
2. Confirm auth session restore behavior is identical in both launch modes.
3. Confirm group list/detail pull-to-refresh works and surfaces errors when enrichment fails.
4. Confirm profile pull-to-refresh reflects remote username/avatar changes.
5. Confirm guest data promotion runs once on first auth for a user and does not regress streak counts.

## Auth settings required for OTP/recovery (all envs)
- Auth -> Sign In / Providers:
  - `Allow new users to sign up`: enabled
  - `Confirm email`: enabled
- Auth -> URL Configuration:
  - Add redirect URL: `sunnad://auth-callback`
- Recovery and signup confirmations now use `sunnad://auth-callback` so no web domain is required for mobile auth flows.

## Dashboard security checklist (dev/prod)
Run this after each auth configuration change:
1. Open Supabase Dashboard -> Security Advisor and confirm no new high-risk warnings.
2. Open Auth -> Settings and ensure `Leaked password protection` is enabled.
3. Re-send signup and recovery emails once to verify templates still include both link and OTP token.
4. Verify redirect URL list still contains `sunnad://auth-callback`.

## Auth resend/rate-limit baseline by environment
Use these as baseline values so users can retry without getting blocked too aggressively:

- local (`supabase/config.toml`):
  - `auth.email.max_frequency = "120s"`
  - `auth.rate_limit.email_sent = 30`
- dev (Dashboard -> Auth -> Rate Limits):
  - minimum resend interval: `120s`
- prod (Dashboard -> Auth -> Rate Limits):
  - minimum resend interval: `180s`

App-side resend cooldown should match environment:
- local/dev: `SUNNAD_AUTH_RESEND_COOLDOWN_SECONDS=120`
- prod: `SUNNAD_AUTH_RESEND_COOLDOWN_SECONDS=180`

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

## Edge Functions (delete-account + send-nudge-push)
- Current function paths:
  - `supabase/functions/delete-account/index.ts`
  - `supabase/functions/send-nudge-push/index.ts`
- Required runtime secrets:
  - `SUPABASE_SERVICE_ROLE_KEY` (both functions)
  - `ONESIGNAL_APP_ID` (`send-nudge-push`)
  - `ONESIGNAL_REST_API_KEY` (`send-nudge-push`)
- Set secrets per project (dev/prod) before deploy:
  - `supabase secrets set SUPABASE_SERVICE_ROLE_KEY=... --project-ref <ref>`
  - `supabase secrets set ONESIGNAL_APP_ID=... ONESIGNAL_REST_API_KEY=... --project-ref <ref>`
- Deploy manually:
  - `supabase functions deploy delete-account --project-ref <ref>`
  - `supabase functions deploy send-nudge-push --project-ref <ref>`
- Behavior notes:
  - `delete-account` now removes profile avatar storage objects (`avatars/profiles/<user_id>/...`) before user deletion.
  - `send-nudge-push` requires authenticated bearer token; if iOS logs show `groups_send_nudge 401`, verify session refresh + function deployment parity.

## Notification toggles contract (iOS)
- Habit reminders toggle:
  - controls local `habit-reminder-*` requests.
- Quote reminder toggle:
  - controls local `quote-reminder-*` requests.
  - schedules a rolling 7-day window at `09:00` local using quote snippets.
- Group reminders toggle (receive-only):
  - when disabled, current device registration is removed from `device_tokens`.
  - when enabled, current device registration is upserted again.

## Sync engine (Stage 7)
- Local SwiftData remains source-of-truth.
- Signed-in mode enables outbox + pull cursors for:
  - `habits`
  - `habit_completions` (rolling 40-day window)
  - `saved_quotes`
  - `quotes`
  - `groups`, `group_members`, `group_shared_habits` snapshots
- Conflict strategy is last-write-wins by `updated_at`.
- Sync triggers:
  - auth sign-in / auth restore
  - foreground refresh cycle
  - background refresh via `BGTaskScheduler` identifier: `com.arystan.almasuly.sunnad-ios.sync.refresh`
- Required iOS config:
  - `Info.plist` includes `BGTaskSchedulerPermittedIdentifiers`
  - `Info.plist` includes `UIBackgroundModes = fetch`
- Diagnostics:
  - `OSLog` category `sync` records cycle start/finish/failures.

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
