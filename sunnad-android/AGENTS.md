# AGENTS.md — /sunnad-android (Sunnad Android app)

This file applies to work inside /sunnad-android. Follow the root AGENTS.md too; if there’s a conflict, this file wins for Android changes. Agents generally read the nearest AGENTS.md for the area being edited.

## Scope
- Native Android app only (Kotlin + Jetpack Compose + Material 3).
- Must not introduce iOS/web patterns here; use modern Material 3 components and Android platform conventions.
- iOS is the behavior reference; Android implementation should mirror behavior, not code.

## Non-negotiables (product parity)
- Exactly 3 tabs (Today / Groups / Profile).
- Today shows ONLY habits scheduled for today.
- Global ordering is respected in Today.
- Weekly schedule supports selecting weekdays.
- Dhikr habits are non-binary; counter is inside Habit Detail.
- Quotes at top of Today; Save + Share; Saved Quotes in Profile.
- i18n required: EN default + RU + KK (Cyrillic). No hardcoded strings.

## Architecture (keep simple)
- MVVM or MVI (pick one that matches existing repo).
- UI = Compose screens; state in ViewModels.
- Local persistence is source of truth (e.g., Room or whatever repo uses).
- Sync optional: only affects logged-in users and Groups.

Current default stack:
- Compose + Material 3 + adaptive navigation shell.
- ViewModel + StateFlow (UDF-style state updates).
- Room for local storage.
- WorkManager for sync/retry/background scheduling.
- Supabase Kotlin client for remote integration behind repository interfaces.

## Android-specific quality rules
- Material 3 typography/color/dark theme.
- Accessibility: content descriptions, touch targets, dynamic font scaling.
- Avoid “custom” UI components unless necessary; prefer Material 3 primitives.
- No hardcoded strings. EN + RU + KK resources are required for all user-facing additions.
- Keep exactly 3 tabs; no temporary extra tabs for internal flows.

## Push notifications (MVP intent)
- Habit reminders: local notifications.
- Friend reminders: remote push via backend; Android just triggers backend calls and handles received notifications.

## Output format
- Plan (3–7 steps)
- Files changed
- How to test (emulator steps)
- Assumptions/TODOs
