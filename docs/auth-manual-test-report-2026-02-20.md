# Auth QA Report (2026-02-20)

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
| Stage-4 smoke SQL (`supabase/tests/stage4_smoke.sql`) | PASS | n/a | n/a | Completed against local DB. |
| iOS unit tests (`sunnad-iosTests`) | PASS | PASS | PASS | Run with iPhone 17 Pro simulator destination. |
| App launch/build (`sunnad-ios`) | PASS | PASS | PASS | Schemes `sunnad-ios`, `sunnad-ios-dev`, `sunnad-ios-prod` launch successfully. |
| Dashboard URL config (`sunnad://auth-callback`) | PASS | PASS | PASS | Verified in Supabase Dashboard pages. |
| Email template placeholders (`{{ .ConfirmationURL }}`, `{{ .Token }}`) | PASS | PASS | PASS | Verified in confirm-sign-up + reset-password templates. |
| Email provider OTP length | PASS | PASS | PASS | Dev updated to `6`; prod already `6`; local from `config.toml`. |
| Email provider min password length | PASS | PASS | PASS | Dev set to `8`; prod already `8`; local validated by config/user setting. |

## Manual Flows Pending Human Confirmation
- Signup via code and via email link (dev/prod)
- Sign-in with username and email (dev/prod)
- Forgot-password code path and link path (dev/prod)
- Resend countdown UX behavior from live device interaction
- Google OAuth end-to-end on simulator and real device
- Delete-account remote deletion verification from user account perspective

## Notes
- No blocking regression found in automated checks.
- Remaining items require interactive account/email/device handling and should be executed with `/Users/alim/Developer/Projects/Apps/Sunnad/docs/auth-manual-test-matrix.md`.
