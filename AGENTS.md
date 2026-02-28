# AGENTS.md — Sunnad (iOS + Supabase)

This file provides project context and working rules for AI coding agents (Codex/Cursor/etc.). The agent should read and follow these instructions before changing code.

## 0) Prime directive

Work like a careful teammate, not an autopilot.

- Prefer small, reviewable changes over big refactors.
- If anything is unclear, ask a short question before coding.
- Don’t “invent” requirements. Follow the PRD / design decisions already in the repo.
- When you propose code, explain the reasoning briefly and list files changed.

## 1) Project snapshot (MVP)

Sunnad is an offline-first habit tracker with:

- Today checklist (only habits scheduled today), streaks, one reminder per habit
- Quote-of-the-day at top of Today with Save + Share
- Dhikr-type habits use a counter inside Habit Detail (not a separate app-level screen)
- Groups-lite accountability (requires login + internet)
- i18n: English default + Russian + Kazakh (Cyrillic). All UI must be translatable.

Implementation status (current):

- iOS is the behavioral reference and has deeper feature maturity.
- Android is being built as native Compose + Material 3 with parity scope.
- Shared backend contracts are preferred over cross-language business-logic reuse.

Non-goals for MVP:

- No Quran/prayer-time reader features
- No extra tabs (exactly 3 tabs: Today / Groups / Profile)
- No “in-app banners” for friend reminders; use real push notifications

## 2) Repo structure (monorepo recommended)

Keep everything in one repo to preserve context across tools/agents:

/sunnad-ios/ iOS app (SwiftUI)
/sunnad-android/ Android app (Kotlin + Material 3 UI)
/supabase/ Supabase local config + migrations + seed
/functions/ Supabase Edge Functions (TypeScript) if/when needed
/admin/ Tiny web admin (can be added later)
/landing/ Landing page for marketing purposes (waitlist, launch, links, terms)

/docs/ PRD, UX notes, schema notes, translations glossary

If you add subdirectories with special rules later, add nested AGENTS.md files there (agents typically use the closest one).

## 3) How to work (required workflow)

Before editing:

1. Read relevant docs (README, /docs, schema notes).
2. State a short plan (3–7 steps).
3. Confirm assumptions if there’s ambiguity.

While editing:

- Keep changes minimal.
- Avoid wide “format the entire codebase” edits.
- Prefer adding tests for logic changes.

After editing:

- Run the relevant checks/tests (see commands below).
- Summarize: what changed, why, how to test.

## 4) Commands agents should use

### iOS (Xcode)

- Build: use Xcode build/test (don’t assume custom scripts unless present).
- Unit tests: run the app’s unit tests target(s) in Xcode.
- If SwiftLint is configured, run it; otherwise don’t add new tooling without asking.

### Android (Gradle)

- Build: `cd sunnad-android && ./gradlew assembleDebug`
- Unit tests: `cd sunnad-android && ./gradlew testDebugUnitTest`
- Instrumentation tests (if emulator available): `cd sunnad-android && ./gradlew connectedDebugAndroidTest`
- Keep `sunnad-android` local-first (Room source of truth + WorkManager sync hooks).

### Supabase (local dev)

Use Supabase CLI if present in the repo.

- Start local stack: `supabase start`
- Create migration: `supabase migration new <name>`
- Apply migrations locally: `supabase db reset` (destructive) OR `supabase db push` (if configured)
- Generate types (if used): keep types in a single source-of-truth location

(If these commands don’t exist yet, ask before adding them and keep setup lightweight.)

## 5) iOS architecture rules (must follow)

Goal: “offline-first + optional sync”, clean separation, predictable state.

- SwiftUI + MVVM-ish:
  - Views are dumb; ViewModels own state and call Services.
  - Business rules live in domain/services, not views.
- Local storage is the source-of-truth:
  - Use SwiftData (or the chosen persistence) for habits, completions, quotes, saved quotes, local-only guest state.
- Sync is additive:
  - Groups + multi-device sync only affect logged-in users.
  - Guest mode never requires network.
  - Write sync so it can be turned off without breaking the app.
- Concurrency:
  - Use async/await; avoid callback pyramids.
  - UI updates on MainActor; networking/storage on background contexts as appropriate.

## 5b) Android architecture rules (must follow)

Goal: parity UX with native Android quality, while preserving offline-first behavior.

- Jetpack Compose + Material 3:
  - Adaptive nav shell with exactly 3 tabs (Today / Groups / Profile).
  - Prefer Material 3 primitives over custom widgets.
- ViewModel + StateFlow:
  - Screens are presentation-first; state/actions in ViewModels.
  - Domain rules live outside composables.
- Local-first:
  - Room is source of truth for habits/completions/quotes/saved quotes/local group snapshots.
  - Remote sync is additive and optional to core tracking behavior.
- Background/sync:
  - WorkManager for retries/background sync orchestration.
  - Sync must be disable-safe.
- Contracts:
  - Treat Supabase migrations/RLS/RPCs as canonical backend behavior.
  - Keep checked contract artifacts in `docs/contracts` and generated DTOs under Android remote data layer.

### UX constraints that affect data model

- Today shows ONLY habits scheduled today (not “all habits”).
- Global reorder exists and applies to Today ordering.
- Weekly schedule supports selecting specific weekdays.
- Only dhikr habits are non-binary (counter).

## 6) Supabase rules (DB/Auth/RLS)

- Treat Postgres + RLS as the security layer.
- Never rely on client-side checks for authorization.
- Every table with user data must have RLS enabled and policies defined.
- Use `auth.uid()`-based ownership rules where possible.
- Never commit secrets (service role keys, JWT secrets, APNS keys).

### When to use Edge Functions vs direct Data API

Default to “no custom backend” unless needed.

Use direct Supabase Data API when:

- Simple CRUD fits RLS policies cleanly (habits, completions, saved quotes).
- No secret-side computation is required.

Use Edge Functions when:

- You must use secrets (APNS push, admin actions).
- You need server-side rate limiting that shouldn’t be bypassable.
- You need “friend reminds friend” to trigger a real push notification.

## 7) Push notifications (MVP intent)

- Local reminders: schedule locally on device (one reminder per habit).
- Friend reminders: server-triggered push via APNS (Edge Function + rate limit).
- Keep the push payload minimal and iOS-native (“Your friend reminded you to complete: <habit>”).

(If APNS key management is not set up yet, do not improvise; ask.)

## 8) Internationalization (must)

- No hardcoded UI strings.
- Use translation keys for all labels/buttons/errors.
- RU + KK translations must fit layouts (dynamic type + truncation).
- Keep a single glossary file in /docs for habit template names and core UI terms.

## 9) What NOT to do

- Don’t add new tabs, major flows, or “nice-to-have” features without approval.
- Don’t replace the stack (SwiftData ⇄ CoreData/GRDB, Supabase ⇄ Firebase, etc.) unless asked.
- Don’t introduce heavy infra (Grafana/K8s) for MVP.
- Don’t add analytics/trackers by default; propose options first.

## 10) Output format expectations

When responding with changes:

- Provide: plan → patch summary → files changed → how to test
- If you couldn’t run tests, say so explicitly.
