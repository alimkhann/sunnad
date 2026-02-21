# Auth QA Report (2026-02-20, updated)

## Scope Executed
- Branch: `codex/stage4-5-auth-supabase`
- Environment matrix attempted: local/dev/prod
- Device matrix executed by agent:
  - iPhone 17 Pro simulator (automated build/run and snapshot checks)
- Real-device execution:
  - pending (requires human-operated sign-in/mail/deep-link interaction)

## Results Matrix
| Area | Local | Dev | Prod | Notes |
|---|---|---|---|---|
| `supabase db reset` + migrations | PASS | n/a | n/a | Includes migrations through `20260220000008_profile_avatar_username.sql`. |
| Hosted migration promotion (`db push`) | n/a | PASS | PASS | Applied `00005`..`00008` to both hosted projects. |
| Hosted edge function deployment (`delete-account`) | n/a | PASS | PASS | `delete-account` deployed via CLI to both project refs. |
| Stage-4 smoke SQL (`supabase/tests/stage4_smoke.sql`) | PASS | n/a | n/a | Completed against local DB. |
| iOS unit tests (`sunnad-iosTests`) | PASS | PASS | PASS | Re-run after env fallback hardening; all tests green. |
| App launch/build (`sunnad-ios`) | PASS | PASS | PASS | Schemes `sunnad-ios`, `sunnad-ios-dev`, `sunnad-ios-prod` launch successfully. |
| Dashboard URL config (`sunnad://auth-callback`) | PASS | PASS | PASS | Verified in Supabase Dashboard pages. |
| Email template placeholders (`{{ .ConfirmationURL }}`, `{{ .Token }}`) | PASS | PASS | PASS | Verified in confirm-sign-up + reset-password templates. |
| Email provider OTP length | PASS | PASS | PASS | Dev updated to `6`; prod already `6`; local from `config.toml`. |
| Email provider min password length | PASS | PASS | PASS | Dev set to `8`; prod already `8`; local validated by config/user setting. |
| Auth API full flow (signup/otp/signin/recovery/password-update/delete) | PASS | BLOCKED | BLOCKED | Hosted returns `429 over_email_send_rate_limit` on signup/recovery using default SMTP. |
| Hosted non-email smoke (function exists, profile avatar column, resolver RPC, provider config) | n/a | PASS | PASS | `delete-account` returns `401` without JWT (expected), `profiles?select=avatar_path` works, `resolve_sign_in_email` callable, Google provider enabled. |

## Manual Flows Pending Human Confirmation
- Dev/prod interactive app flows on simulator and real device:
  - Signup via code and via email link
  - Sign-in with username and email
  - Forgot-password code path and link path
  - Resend countdown UX behavior
  - Google OAuth end-to-end
  - Delete-account remote deletion from UI perspective

## Notes
- Env fallback is now explicit opt-in (`SUNNAD_ENABLE_LOCAL_SUPABASE_FALLBACK=1`) to prevent silent local leakage when dev/prod env vars are missing.
- Hosted email-path auth QA is currently constrained by Supabase default outbound email limits; full hosted manual verification should be run after SMTP/rate-limit capacity is available.
- Remaining items require interactive account/email/device handling and should be executed with `/Users/alim/Developer/Projects/Apps/Sunnad/docs/auth-manual-test-matrix.md`.
