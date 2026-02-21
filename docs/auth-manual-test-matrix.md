# Auth Manual Test Matrix (Local / Dev / Prod)

## Preconditions
- Supabase target environment is running and reachable.
- Use the correct scheme for the environment:
  - local: `sunnad-ios`
  - dev: `sunnad-ios-dev`
  - prod: `sunnad-ios-prod`
- `sunnad://auth-callback` exists in Supabase redirect URLs.
- For Google OAuth tests: provider must be enabled in that Supabase project.

## 1) Signup (email/password)
1. Open app as guest.
2. Go to Sign Up.
3. Submit valid email + username + password.
4. Verify OTP screen appears.
5. Check email contains both:
- link (`ConfirmationURL`)
- 6-digit code (`Token`)
6. Enter code manually -> user is signed in and routed to Today tab.
7. Repeat with link tap -> app opens and routes to Today tab.

## 2) Sign in (email or username)
1. Sign out.
2. Sign in with email + password.
3. Sign out.
4. Sign in with username + password.
5. Confirm both succeed and session is restored after relaunch.
6. Enter wrong password once and confirm localized invalid-credentials error is shown.

## 3) Forgot password
1. From Sign In, open Forgot Password.
2. Submit account email.
3. Verify recovery OTP screen opens.
4. Check email contains both link and code.
5. Manual path:
- enter code in recovery OTP screen
- app opens Change Password
- update password
- app routes to Today tab and stays signed in
6. Link path:
- tap reset link
- app opens Change Password
- update password
- app routes to Today tab and stays signed in

## 4) Resend cooldown and reliability
1. On OTP screen, tap resend once.
2. Verify button becomes disabled and shows countdown (`60 -> 0`).
3. Verify button re-enables at zero.
4. Tap resend again and verify second email arrives.
5. Repeat for both signup OTP and recovery OTP flows.

## 5) OAuth buttons
1. Google button:
- enabled in envs where configured
- successful sign-in routes to Today tab
2. Apple button:
- visible but disabled while `SUNNAD_AUTH_APPLE_ENABLED=0`
- helper text indicates unavailable/coming soon

## 6) Guest safety regression
1. Launch app and continue as guest.
2. Use Today tab features offline.
3. Ensure no forced network/auth requirement appears.

## 7) Environment separation checks
1. Dev scheme uses dev URL/key only.
2. Prod scheme uses prod URL/key only.
3. User created in dev does not exist in prod.
4. Email template behavior (link + code) is identical in local/dev/prod.
5. Installed app name matches scheme environment:
- local: `Sunnad Local`
- dev: `Sunnad Dev`
- prod: `Sunnad`

## 7.1) Launch-mode parity checks (critical)
1. Launch from Xcode and sign in.
2. Stop from Xcode.
3. Launch the same installed app from simulator/device icon.
4. Confirm session is still restored (no forced guest fallback).
5. Repeat once per environment scheme.

## 8) Profile editing (signed-in users)
1. Open Profile tab and tap account card.
2. Change username to a valid lowercase value (`[a-z0-9_]{3,20}`) and save.
3. Confirm success toast appears and account card updates immediately.
4. Try invalid username (uppercase/spaces/symbols/too short) and confirm save remains disabled or fails with validation.
5. Upload avatar image and confirm card updates.
6. Remove avatar and confirm default icon restores.
7. Pull down to refresh Profile and confirm username/avatar remain consistent with remote state.
8. Confirm debug diagnostics line (debug builds) shows `bundle id | supabase host | namespace`.

## 9) Delete account semantics
1. While signed in, use `Delete Account`.
2. Confirm copy states remote account/data deletion and local on-device data retention.
3. Confirm app transitions to guest mode without onboarding reset.
4. Confirm local habits/quotes still exist on device.
5. Confirm old credentials no longer authenticate against that environment.

## 10) Execution matrix
Run sections 1-9 in:
- local on iPhone 17 Pro simulator
- dev on iPhone 17 Pro simulator
- prod on iPhone 17 Pro simulator
- dev on real device
- prod on real device

For dev/prod, run each row in both launch modes:
- launched from Xcode
- launched from icon

## 11) Groups + refresh regression
1. Sign in and open Groups tab.
2. Pull down to refresh group list.
3. Open a group detail and pull down to refresh detail.
4. Verify group create/join entries appear without relaunch.
5. Verify group rename/lock/rotate actions still work.
6. If network enrichment fails, verify user sees a recoverable error message (not silent empty state).
7. Verify bell nudge action shows recoverable status (sent/duplicate/forbidden/error).

## 12) Guest promotion + streak sanity
1. As guest, create a habit and mark one completion for today.
2. Sign up/sign in and verify guest data appears immediately in signed-in scope.
3. Sign out and verify guest scope still has original guest data.
4. In a non-UTC timezone, verify a single completion yields streak `1` (never `2`) after sync and relaunch.
