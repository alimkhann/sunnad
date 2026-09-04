# Apple + OneSignal Setup

This is the release checklist for enabling remote iOS nudges and Sign in with Apple using the current Sunnad architecture:

- iOS app -> OneSignal SDK
- OneSignal -> APNs
- Supabase Auth -> Apple provider
- Supabase Edge Function -> OneSignal REST API

## 1. Apple Developer

For each app bundle ID, enable both capabilities:

- `com.arystan.almasuly.sunnad.local`
- `com.arystan.almasuly.sunnad.dev`
- `com.arystan.almasuly.sunnad`

Required capabilities:

- Push Notifications
- Sign in with Apple

Create and save:

1. APNs auth key (`.p8`)
2. APNs Key ID
3. Apple Team ID
4. Apple Sign in key / client credentials used by Supabase

If Apple asks for callback URLs for Sign in with Apple, use the Supabase callback for each hosted project:

- `https://wejnrzlxnesqhbtvgdga.supabase.co/auth/v1/callback`
- `https://artwfvypcdacdpqhciqt.supabase.co/auth/v1/callback`

## 2. OneSignal

Create or update the iOS app in OneSignal.

Use the APNs auth key from Apple Developer:

- upload the `.p8`
- set the APNs Key ID
- set the Apple Team ID
- set the exact iOS bundle ID for the environment

Record:

- OneSignal App ID
- OneSignal REST API key

Current Xcode build settings already read:

- `SUNNAD_ONESIGNAL_APP_ID_BUNDLE`
- `SUNNAD_ONESIGNAL_APP_GROUP_ID_BUNDLE`

## 3. Supabase Auth

For each hosted project:

1. Open `Auth -> Sign In / Providers -> Apple`
2. Enable Apple
3. Paste the Apple credentials from Apple Developer
4. Keep the mobile redirect URL enabled:
   - `adat://auth-callback`

The app now performs native Apple auth on iOS and exchanges the Apple identity token with Supabase.

## 4. Supabase Edge Function Secrets

Set the following secrets on dev and prod:

- `SUPABASE_SERVICE_ROLE_KEY`
- `ONESIGNAL_APP_ID`
- `ONESIGNAL_REST_API_KEY`

Deploy or redeploy:

```bash
supabase functions deploy send-nudge-push --project-ref <ref>
```

## 5. Xcode / Signing

The repo already includes:

- OneSignal app group entitlement in `sunnad-ios/sunnad-ios/sunnad-ios.entitlements`
- Notification service extension target in `sunnad-ios/sunnad-ios.xcodeproj`
- Apple sign-in entitlement in `sunnad-ios/sunnad-ios/sunnad-ios.entitlements`

Still verify in Signing & Capabilities for each app target:

- Push Notifications
- Sign in with Apple
- App Groups

Also verify the notification extension target has:

- App Groups
- a valid provisioning profile
- an environment-specific bundle ID

## 6. Real Device Validation

Push delivery must be tested on a physical iPhone.

Checklist:

1. Install dev build on device
2. Sign in with Apple
3. Confirm the user exists in Supabase Auth
4. Confirm a row appears in `public.device_tokens`
5. Trigger a group nudge
6. Confirm `send-nudge-push` returns `status=sent`
7. Confirm the notification arrives on the device

## 7. Post-Setup Notes

- Apple sign-in button visibility is controlled by `SUNNAD_AUTH_APPLE_ENABLED_BUNDLE`
- Remote nudge delivery currently uses OneSignal; do not replace it with direct APNs unless the backend is redesigned
- iOS simulator is not enough for APNs verification
