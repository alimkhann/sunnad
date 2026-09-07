# Apple Push (Native APNs) Setup

> Superseded: OneSignal was removed from the iOS app and the backend in favor of
> direct APNs delivery from the `send-nudge-push` Edge Function. This document
> describes the current native flow. Runtime secret details live in
> `docs/supabase-environments.md` ("Edge Functions" section).

Current architecture:

- iOS app registers the APNs token and upserts it to Supabase (`device_tokens`)
- Supabase Edge Function (`send-nudge-push`) signs an ES256 provider token and
  POSTs directly to APNs (sandbox or production per token row)
- Supabase Auth -> Apple provider (unchanged)

## 1. Apple Developer

For each app bundle ID, enable both capabilities:

- `com.arystan.almasuly.sunnad.local`
- `com.arystan.almasuly.sunnad.dev`
- `com.arystan.almasuly.sunnad`

Required capabilities:

- Push Notifications
- Sign in with Apple

Create and save (outside the repo, e.g. `~/secrets/`):

1. APNs auth key (`.p8`) — downloadable only once at creation
2. APNs Key ID
3. Apple Team ID
4. Apple Sign in key / client credentials used by Supabase

If Apple asks for callback URLs for Sign in with Apple, use the Supabase callback for each hosted project:

- `https://wejnrzlxnesqhbtvgdga.supabase.co/auth/v1/callback`
- `https://artwfvypcdacdpqhciqt.supabase.co/auth/v1/callback`

## 2. Supabase Auth

For each hosted project:

1. Open `Auth -> Sign In / Providers -> Apple`
2. Enable Apple
3. Paste the Apple credentials from Apple Developer
4. Keep the mobile redirect URL enabled:
   - `adat://auth-callback`

The app performs native Apple auth on iOS and exchanges the Apple identity token with Supabase.

## 3. Supabase Edge Function Secrets (native APNs)

Set the following secrets on dev and prod (see `docs/supabase-environments.md` for the full list):

```bash
supabase secrets set --project-ref <ref> \
  APNS_TEAM_ID=<TEAMID10> \
  APNS_KEY_ID=<KEYID10> \
  APNS_PRIVATE_KEY="$(cat ~/secrets/AuthKey_<KEYID10>.p8)" \
  APNS_BUNDLE_ID_DEV=com.arystan.almasuly.sunnad.dev \
  APNS_BUNDLE_ID_PROD=com.arystan.almasuly.sunnad
```

Per-environment topic mapping used by the function:

- token row `apns_environment = development` -> `api.sandbox.push.apple.com` + topic `APNS_BUNDLE_ID_DEV`
- token row `apns_environment = production` (or NULL) -> `api.push.apple.com` + topic `APNS_BUNDLE_ID_PROD`

Deploy or redeploy:

```bash
supabase functions deploy send-nudge-push --project-ref <ref>
```

## 4. Xcode / Signing

The repo already includes:

- Apple sign-in + aps-environment entitlements in `sunnad-ios/sunnad-ios/sunnad-ios.entitlements`
- Per-configuration APNs environment via `SUNNAD_APNS_ENVIRONMENT_BUNDLE`
  (Debug=development, Release=production)

Verify in Signing & Capabilities for the app target:

- Push Notifications
- Sign in with Apple

## 5. Real Device Validation

Push delivery must be tested on a physical iPhone (the simulator cannot receive APNs).

Checklist:

1. Install build on device
2. Sign in
3. Grant notification permission (token registration is gated on it)
4. Confirm a row appears in `public.device_tokens` with a 64-hex `token` and the
   expected `apns_environment`
5. Trigger a group nudge
6. Confirm `send-nudge-push` returns `{"status":"sent","delivered":true}`
7. Confirm the notification arrives on the device

## 6. Post-Setup Notes

- Apple sign-in button visibility is controlled by `SUNNAD_AUTH_APPLE_ENABLED_BUNDLE`
- Remote nudge delivery uses direct APNs from the Edge Function; OneSignal is fully removed
- The function deletes `device_tokens` rows that APNs reports as invalid; the app
  re-registers the token on the next foreground/sign-in, so recovery is automatic
- iOS simulator is not enough for APNs verification
