# Android Parity Checklist

Use this checklist for every visual iteration before declaring parity complete.

## Routing and Startup
- Fresh install opens onboarding welcome.
- Completed onboarding guest opens main tabs (no inline auth form in Profile).
- Authenticated session opens main tabs directly.
- Auth callback (`sunnad://auth-callback`) returns to app and resolves session.
- If auth backend is unavailable, user can still continue as guest and reach main tabs.

## Auth and Onboarding
- Onboarding flow: welcome -> templates -> notifications -> join groups.
- Sign-in route is full-screen (not embedded in Profile).
- Sign-up + OTP verification path works.
- Password reset and OTP recovery path works.
- Google auth callback path works.
- Apple entry is visible and degrades gracefully if unavailable.

## Visual IA Parity
- Today: title + top action capsule (manage/add), quote card, progress, pending list, collapsible completed section.
- Groups: guest CTA state and signed-in list/detail state are visually distinct.
- Profile: sectioned rows and settings sheets/dialogs; no form-heavy inline blocks.
- No oversized blank zones and no overlapping top content.

## Accessibility and i18n
- Tap targets >= 48dp.
- Content descriptions exist for actionable icons.
- EN/RU/KK all render without clipping on primary controls.
- Font scale 1.15 remains readable and scrollable.

## Artifacts
- Confirm capture mode used:
  - `mobile-mcp` active in session, or
  - `adb` fallback scripts.
- Captures stored with schema: `docs/android/parity/<iteration>/<screen>/<theme>/<locale>.png`.
- Each iteration includes dark + light for EN/RU/KK.
- Capture set references iOS shots in `landing/public/app-screenshots` during review.

## Latest Iteration Notes
- `iteration-05` captured on Android emulator (`emulator-5554`) for:
  - onboarding welcome/templates/notifications/join-groups
  - auth sign-in
  - main tabs guest states (Today/Groups/Profile)
- Runtime regression addressed in this iteration:
  - Supabase/Ktor engine crash on launch fixed (`ktor-client-okhttp` + explicit `OkHttp` engine).
  - Onboarding guest completion now transitions to main tabs reliably on first tap.
