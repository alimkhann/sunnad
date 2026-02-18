# AGENTS.md — /sunnad-ios (Sunnad iOS app)

This file applies to work inside /sunnad-ios. Follow the root AGENTS.md too; if there’s a conflict, this file wins for iOS changes. Agents generally read the nearest AGENTS.md for the area being edited.

## Scope
- Native iOS app (SwiftUI).
- Offline-first is the default. Network is optional and mainly required for Groups + multi-device sync (logged-in users).
- Must keep product constraints: exactly 3 tabs (Today / Groups / Profile). No extra tab for Manage.

## Non-negotiables (UX constraints)
- Today shows ONLY habits scheduled for today.
- Global ordering: user-defined order is the default for Today list.
- Weekly schedule supports picking specific weekdays.
- Only dhikr habits are non-binary; dhikr counter lives inside Habit Detail (Details <-> Counter switch).
- Quotes: shown at top of Today; Save + Share; Saved Quotes accessible from Profile.
- i18n required: EN default + RU + KK (Cyrillic). No hardcoded strings anywhere.

## Architecture (keep simple, don’t over-engineer)
- MVVM-ish:
  - Views: presentation only.
  - ViewModels: state + user actions.
  - Services/Repositories: business + data access.
- Local persistence is source of truth (SwiftData for MVP unless the repo says otherwise).
- Sync layer must be separable (can be disabled without breaking offline use).

Suggested folders (only if it fits current repo):
- /sunnad-ios/App (entry, DI composition)
- /sunnad-ios/Features (Today, Habits, Groups, Profile)
- /sunnad-ios/Domain (models + pure rules)
- /sunnad-ios/Data (storage, repositories, sync clients)
- /sunnad-ios/Shared (design tokens, helpers, localization)

## Concurrency & UI updates
- Use async/await for IO.
- UI state updates must happen on the main actor (don’t update SwiftUI state from background threads).

## Localization rules
- All user-facing text uses localization keys.
- Keep keys stable and descriptive (e.g., today_title, habits_manage_title).
- Provide EN/RU/KK translations for every key you introduce.
- Ensure long RU strings and KK Cyrillic fit (Dynamic Type, truncation where needed).

## Liquid Glass policy (system-only)
- Use system-provided bar/sheet/toolbar appearance only; do not add custom Liquid Glass/material effects to content.
- Do not use `glassEffect`, `GlassEffectContainer`, or `.ultraThinMaterial/.thinMaterial/.regularMaterial/.thickMaterial` in content rows, cards, or full-screen backgrounds.
- Any exception requires explicit product/design review approval.

## Build/test expectations
- Don’t add new tools (SwiftLint/SwiftFormat) unless asked.
- If you touch domain logic, add/adjust unit tests.
- Keep changes small, avoid refactors that churn unrelated files.

## Push notifications (MVP intent)
- Habit reminders: local notifications.
- “Remind a friend”: remote push via backend; iOS should only call a backend endpoint and handle the received notification. Don’t implement server logic in iOS.

## Output format (when proposing code)
- Plan (3–7 steps)
- Files changed
- How to test manually in simulator
- Any assumptions or TODOs
