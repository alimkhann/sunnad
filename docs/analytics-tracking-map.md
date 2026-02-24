### Analytics tracking map

This document summarizes the PostHog analytics events implemented for the Sunnad landing site and iOS app, with their properties and emission points. All events are designed to avoid PII (no emails, usernames, join codes, or quote text).

---

### Web (landing)

- **Event**: `landing_viewed`  
  - **Properties**:
    - `locale` (string) – `"en" | "ru" | "kk"`
    - `theme` (string) – `"dark" | "light"`
    - `path` (string) – browser path, e.g. `"/en"`
    - `referrer_domain` (string, optional) – hostname from `document.referrer`
    - `utm_source` / `utm_medium` / `utm_campaign` / `utm_content` / `utm_term` (string, optional) – UTM query params  
  - **Code**: `landing/features/landing/page.tsx`, `LandingPage` `useEffect` near the top of the component.

- **Event**: `waitlist_submitted`  
  - **Properties**:
    - `status` (string) – `"subscribed" | "already_subscribed"`
    - `locale` (string) – user locale passed to submit function
    - `variant` (string) – waitlist variant identifier
    - `platform` (string) – `"ios" | "android" | "unknown"` (from user agent)
    - `referral_source` (string) – `"landing"`  
  - **Code**: `landing/lib/waitlist-submit.ts`, `trackWaitlistSubmitted`.

- **Event**: `waitlist_submit_failed`  
  - **Properties**:
    - `status` (string) – `"rate_limited" | "error"`
    - `locale` (string) – user locale passed to submit function
    - `variant` (string) – waitlist variant identifier
    - `platform` (string) – `"ios" | "android" | "unknown"`
    - `referral_source` (string) – `"landing"`
    - `error_type` (string) – `"rate_limited" | "http_<code>" | "network" | "unexpected_response"`  
  - **Code**: `landing/lib/waitlist-submit.ts`, `trackWaitlistFailed` and uses in `submitWaitlist`.

---

### iOS – shared client configuration

- **Client**: `PostHogAnalyticsClient`  
  - **Code**: `sunnad-ios/sunnad-ios/Services/Logging/AnalyticsClient.swift`.  
  - **Behavior**:
    - Reads PostHog key from `SUNNAD_POSTHOG_API_KEY` (env) or `SunnadPosthogApiKey` (Info.plist).
    - Uses host from `SUNNAD_POSTHOG_HOST` or `SunnadPosthogHost`, defaulting to `https://eu.i.posthog.com`.
    - Disables autocapture: `captureApplicationLifecycleEvents = false`, `captureScreenViews = false`, `captureElementInteractions = false`, `enableSwizzling = false`.
    - Enables anonymous reuse: `reuseAnonymousId = true`.
    - Respects environment-aware toggle: enabled in production by default, overridable with `SUNNAD_ANALYTICS_ENABLED` in debug.
    - Adds base properties to all events:
      - `app_version`, `build_number`, `platform = "ios"`, `environment`, `locale`.

- **No-op client**: `NoopAnalyticsClient`  
  - **Code**: same file as above. Used when key/host are not configured.

- **DI wiring**  
  - **Code**: `sunnad-ios/sunnad-ios/App/DependencyContainer.swift`  
  - **Behavior**:
    - Exposes `let analytics: AnalyticsClient`.
    - Chooses `PostHogAnalyticsClient` when configuration is valid, otherwise `NoopAnalyticsClient`.

---

### iOS – lifecycle and navigation

- **Event**: `app_opened`  
  - **Properties**: base properties only.  
  - **Code**: `sunnad-ios/sunnad-ios/sunnad_iosApp.swift`, in `.onAppear` for `SunnadRootView`, via `dependencies.analytics.trackLifecycle(.appOpened)`.

- **Event**: `app_backgrounded`  
  - **Properties**: base properties only.  
  - **Code**: same file, in `.onChange(of: scenePhase)` when phase becomes `.background`, via `trackLifecycle(.appBackgrounded)`.

- **Screens**  
  - **Helper**: `AnalyticsClient.trackScreen(_:)`  
  - **Code**: `sunnad-ios/sunnad-ios/Services/Logging/AnalyticsEvents.swift`.  
  - **Note**: ready for use in tab/view transitions (e.g. Today/Groups/Profile) by calling `dependencies.analytics.trackScreen(.today)` etc. No PII is included, only `screen_name`.

---

### iOS – onboarding

- **Helper**: `AnalyticsClient.trackOnboarding(_:)`  
  - **Code**: `AnalyticsEvents.swift`.

- **Events and properties**:
  - `onboarding_started` – (not yet emitted; helper exists).
  - `onboarding_template_selected`
    - `template_count` (int) – number of templates selected.  
    - **Emission**: `AppRouteState.moveOnboardingForward`, when advancing from `.templates` to `.notifications`.
  - `onboarding_notifications_prompted`
    - **Emission**: `AppRouteState.moveOnboardingForward`, when advancing from `.notifications` to `.joinGroups`.
  - `onboarding_notifications_enabled`
    - **Emission**: `AppRouteState.enableOnboardingNotifications`.
  - `onboarding_notifications_skipped`
    - **Emission**: `AppRouteState.skipOnboardingNotifications`.
  - `onboarding_completed`
    - **Emission**: `AppRouteState.moveOnboardingForward`, when advancing from `.joinGroups` and completing as guest.

All properties are counts/booleans or enums – no template names.

---

### iOS – auth

- **Helper**: `AnalyticsClient.trackAuth(kind:provider:status:reason:)`  
  - **Code**: `AnalyticsEvents.swift`.
  - **Properties**:
    - `kind` – `"sign_in" | "sign_up"`.
    - `provider` – `"email" | "google" | "apple"`.
    - `status` – `"success" | "failure"`.
    - `reason` – coarse string for failures, e.g. `"error"`.

- **Event names**:
  - `auth_sign_in_success` / `auth_sign_in_failed`
  - `auth_sign_up_success` / `auth_sign_up_failed`

- **Emission points**:
  - `auth_sign_in_success` / `auth_sign_in_failed`
    - **Code**: `AppRouteState.handleSignIn`, after auth service result.
  - `auth_sign_up_*` and social providers:
    - **Code**: `AppRouteState.handleGoogleSignIn`, `handleGoogleSignUp`, `handleAppleSignIn`, `handleAppleSignUp` (currently tracking successful intent dispatch; failures are still captured via `analyticsLogger` and can be extended to track PostHog failures if desired).

No emails, usernames, or error messages are sent to PostHog; only coarse `reason` for failures.

---

### iOS – identity and guest behavior

- **Identify**  
  - **Code**: `AppRouteState.identifySignedInUser(_:)`.  
  - **Behavior**:
    - Called at the end of `syncSignedInSession(_:trigger:promotionMode:)` for any successful auth/restore.
    - Uses:
      - `distinct_id` – `SessionUser.id.uuidString`.
      - `userProperties`:
        - `is_guest = false`
        - `language` (UI language code)
        - `locale` (locale identifier).
      - `userPropertiesSetOnce`:
        - `first_seen_at` – ISO8601 timestamp string.

- **Reset / guest**  
  - **Code**: `AppRouteState.signOut`, `AppRouteState.deleteAccount`.  
  - **Behavior**:
    - Calls `dependencies.analytics.reset()` after sign-out / account deletion.
    - With `reuseAnonymousId = true` in config, PostHog reuses a stable anonymous device ID across guest sessions.
    - Guest events are anonymous and only carry base properties; no PII is included.

---

### iOS – habits, quotes, groups, sync

The following helpers are implemented in `AnalyticsEvents.swift` and ready for use at key domain boundaries. They currently emit events with only IDs, enums, or counts – never habit names, quote text, group names, or join codes:

- **Habits** (`AnalyticsClient.trackHabit(_:)`)
  - `habit_created` – `type`, `schedule_type`, `has_reminder`.
  - `habit_edited` – `changed_fields` (string array of field identifiers).
  - `habit_archived` / `habit_unarchived`.
  - `habit_completed` – `type`, `source`, `count` (for dhikr).
  - `habit_uncompleted`.
  - `habit_reminder_enabled` / `habit_reminder_disabled`.
  - `habit_counter_incremented` – `type`, `delta`.

- **Quotes** (`trackQuote(_:)`)
  - `quote_viewed`, `quote_saved`, `quote_unsaved`.
  - `quote_shared` – optional `channel` (e.g. `"system_share_sheet"`). No quote text is sent.

- **Groups** (`trackGroup(_:)`)
  - `group_opened`, `group_created`.
  - `group_join_started`, `group_join_succeeded`, `group_join_failed` (with coarse `reason`).
  - `group_left`.
  - `group_member_viewed` – `count` only; no member identifiers.
  - `group_sharing_updated` – `delta` (change in shared count).
  - `nudge_sent` – `habit_type` only (no habit name).
  - `nudge_failed` – coarse `reason`.

- **Sync** (`trackSync(_:)`)
  - `sync_started` – `trigger` (`"foreground" | "manual" | "background"`).
  - `sync_succeeded` – `duration_ms`, `pulled_count`, `pushed_count`.
  - `sync_failed` – `stage`, `error_code`, `duration_ms`.

These helpers are intended to be called from:
  - `TodayViewModel`, `GroupsViewModel`, `ProfileViewModel`, and sync-related services when the corresponding domain actions occur.
  - `AppRouteState` for high-level flows (e.g., sync triggers and group operations).

---

### Data quality and privacy guarantees

- No PostHog event includes:
  - Email addresses
  - Usernames or display names
  - Habit names
  - Quote text
  - Group names or invite/join codes
- All properties are enums, IDs, counts, booleans, or coarse reason strings.
- Environment and app metadata are attached automatically via `PostHogAnalyticsClient` base properties.

