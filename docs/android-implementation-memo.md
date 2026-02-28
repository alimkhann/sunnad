# Android Implementation Memo (UI-first parity)

## Decision
Sunnad Android will be implemented as a native Kotlin app (Jetpack Compose + Material 3) with duplicated domain logic and shared backend contracts.

We are not reusing Swift code directly on Android. iOS remains the behavior reference, and Kotlin ports are validated by parity unit tests.

## Why this path
- Fastest route to high-quality native UX on Android.
- Lower migration risk than immediate KMP extraction.
- Keeps backend behavior aligned via shared contract artifacts sourced from Supabase schema/RPCs.

## Locked architecture
- UI: Compose + Material 3, adaptive shell (`NavigationSuiteScaffold`), edge-to-edge.
- State: ViewModel + `StateFlow`.
- Local storage: Room as source of truth.
- Sync/background: WorkManager + sync coordinator.
- Remote: Supabase Kotlin client (community-maintained).
- Auth: email/password/OTP + Google; Apple auth is prewired and non-blocking.
- Notifications: local reminders + remote friend reminder receive path.
- i18n: EN, RU, KK required from first Android release.

## Staged delivery
1. Foundation: docs, AGENTS, Gradle dependencies, app shell, architecture skeleton.
2. Local-first core: Room schema, repository interfaces, domain rules port + tests.
3. Feature parity baseline: Today/Habits/Profile with quote save/share and dhikr detail counter.
4. Connected parity: auth, groups governance, sync, notifications.
5. Hardening: i18n QA, accessibility, CI gates, release checklist.

## KMP gate (explicitly deferred)
KMP domain extraction is deferred until after Android parity unless duplication pain is confirmed by repeated cross-platform rule fixes over multiple sprints.

## Contract strategy
- Canonical source of truth: `supabase/migrations/*.sql`.
- Checked artifact: `docs/contracts/postgrest.openapi.json`.
- Android DTO namespace: `sunnad-android/app/src/main/java/.../data/remote/generated`.
- Generation scripts are deterministic and can be run in CI.

## Current implementation status
This memo is paired with initial Android parity scaffolding in `/sunnad-android`:
- Material 3 adaptive shell with Today/Groups/Profile tabs.
- Room entities/DAO/database and owner-scope model.
- Kotlin port of iOS domain rules with parity unit tests.
- Sync/auth/notification interfaces with no-op and scaffold implementations.
- Baseline feature viewmodels/screens and EN/RU/KK resources.
