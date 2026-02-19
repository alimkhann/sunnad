# Sunnad Architecture (MVP)

## Core principles
- Offline-first by default.
- SwiftData is the local source of truth.
- Supabase is a sync target for signed-in users.
- Groups and friend accountability require authentication.

## iOS layering
- `Features/*/Views`: presentation only (SwiftUI screens).
- `Features/*/ViewModels`: state and user actions.
- `Domain/*`: pure models and business rules.
- `Data/Local/*`: SwiftData entities and repositories.
- `Data/Remote/*`: reserved for Supabase repositories (future stage).
- `Services/*`: cross-cutting services (notifications, logging, auth, sync).
- `App/*`: dependency composition and app routing state.

## Source of truth and sync model
- Guest mode uses local storage only.
- Logged-in mode keeps local-first behavior and adds best-effort sync.
- Sync can be disabled without breaking core habit tracking.

## Tabs and scope
- Exactly 3 tabs: Today, Groups, Profile.
- Today includes quote of the day and due habits only.
- Dhikr counter stays inside habit detail.

## Notifications
- Habit reminders: local iOS notifications.
- Friend reminders: server-triggered push in later Supabase/Edge stage.

## Supabase stage-4 contracts
- Group creation is server-owned via `public.create_group_with_owner(group_name text)`.
- Group joins use `public.join_group_by_code(invite_code text)` with normalized, case-insensitive codes.
- Habit ownership is enforced across linked tables with composite foreign keys:
  - `habit_completions(user_id, habit_id) -> habits(user_id, id)`
  - `group_shared_habits(user_id, habit_id) -> habits(user_id, id)`
- Sync-readiness metadata includes `updated_at` on `group_members` and `saved_quotes`.

## Backend hardening constraints
- `habits.schedule` is restricted to `daily` or `weekly`.
- Ownership and membership checks are enforced in both RLS policies and table constraints.
- New smoke SQL (`supabase/tests/stage4_smoke.sql`) validates group create/join/share/nudge paths.

## Localization
- English default, plus Russian and Kazakh (Cyrillic).
- UI strings must be localization-key based.
