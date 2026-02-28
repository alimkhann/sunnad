# Android Manual Test Matrix

## Scope
Android parity checks for onboarding/auth/main routing, visual hierarchy parity, local-first behavior, sync hooks, reminders, and localization.

## Preconditions
- Build from `sunnad-android` using debug variant.
- Emulator timezone settable (test UTC and Asia/Almaty).
- Supabase local/dev configured if remote tests are executed.

## Core behavior
1. Today shows only due habits for current day.
2. Weekly schedule honors selected weekdays.
3. Global order is reflected in Today list order.
4. Dhikr counter works only in habit detail and clamps to target.
5. Quote of day is deterministic by locale/day and can be saved/shared.

## Startup routing
1. Fresh install opens onboarding welcome.
2. Completed onboarding + guest opens main tabs without inline auth in Profile.
3. Authenticated session opens main tabs directly.
4. Deep-link callback `sunnad://auth-callback` returns to app and session is restored.

## Onboarding/auth
1. Welcome -> templates -> notifications -> join groups route progression.
2. Profile guest CTA opens full-screen sign-in route.
3. Groups guest CTA opens full-screen sign-in route.
4. Sign-up -> OTP verify and password-reset -> OTP recovery complete end-to-end.

## Groups
1. Create, join, rename, lock/unlock, rotate code, leave/delete.
2. Sharing toggles update local state and repository call path.
3. Nudge action invokes send path and handles duplicate/forbidden states.

## Profile/auth/settings
1. Language switch updates all labels for EN/RU/KK.
2. Appearance and reminder preferences persist after app relaunch.
3. Email/password/OTP and Google entry points work or fail gracefully by config.
4. Apple auth button/path is prewired and non-crashing when unavailable.

## Sync/offline
1. Local habit/completion/saved quote writes are immediate offline.
2. Sync coordinator can be triggered manually and from foreground/background hooks.
3. Outbox items persist and retry policy executes without app crash.

## Notifications
1. One local reminder per habit scheduling path.
2. Reminder updates when habit reminder time changes.
3. Remote friend reminder receive path displays notification.

## Accessibility/adaptive
1. Touch targets are >= 48dp.
2. Screen-reader labels exist for actionable controls.
3. Dynamic font scale keeps layout usable.
4. Tablet and foldable use adaptive navigation behavior.

## Visual parity captures
1. Capture required screens/themes/locales into `docs/android/parity/<iteration>/...`.
2. Compare against iOS references in `landing/public/app-screenshots`.
3. Run checklist in `docs/android/parity/checklist.md` every iteration.
