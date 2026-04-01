# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Sunnad/Adat is an offline-first Islamic habit tracker with group accountability. Multi-platform monorepo: iOS (SwiftUI), Android (Kotlin Compose), web (Next.js landing + admin), and Supabase backend.

iOS is the **behavioral reference** — Android targets feature parity. Guest mode works fully offline; sync and groups require authentication.

## Monorepo Layout

- `sunnad-ios/` — iOS app (SwiftUI + SwiftData, Xcode project)
- `sunnad-android/` — Android app (Jetpack Compose + Room + Material 3, Gradle)
- `supabase/` — Postgres migrations, Edge Functions, config
- `landing/` — Next.js 16 marketing site (TypeScript, Tailwind)
- `admin/` — Next.js 15 admin dashboard (quote management)
- `docs/` — Architecture, contracts, runbooks, test matrices
- `scripts/` — DB backup/restore, contract generation, dev helpers

## Build & Development Commands

### iOS
Build and test through Xcode. No custom build scripts. Targets: `sunnad-ios`, `sunnad-iosTests`, `sunnad-iosUITests`, `sunnad-iosNotificationServiceExtension`.

### Android
```bash
cd sunnad-android && ./gradlew assembleDebug
cd sunnad-android && ./gradlew testDebugUnitTest
cd sunnad-android && ./gradlew connectedDebugAndroidTest  # requires emulator
```
Build flavors: `prod` (production Supabase) and `dev`.

### Supabase
```bash
supabase start                          # local stack
supabase db reset                       # destructive: reapply all migrations + seed
supabase db push                        # incremental push
supabase migration new <name>           # new migration
supabase functions deploy               # deploy edge functions
```

### Landing Page
```bash
cd landing && npm run dev               # localhost:3000
cd landing && npm run build
cd landing && npm run lint              # tsc --noEmit
```

### Admin Dashboard
```bash
cd admin && npm run dev
cd admin && npm run build
cd admin && npm run lint
```

### Contract Generation
```bash
scripts/contracts/generate_postgrest_openapi.sh
scripts/contracts/generate_android_dtos.sh
scripts/contracts/check_android_contract_drift.sh
```

## Architecture

### Shared Principles
- **Offline-first**: SwiftData (iOS) / Room (Android) are source of truth
- **Sync is additive**: can be disabled without breaking core habit tracking
- **Guest mode**: no network required for habit tracking
- **Exactly 3 tabs**: Today / Groups / Profile — no extras without approval
- **Today tab**: shows only habits scheduled for today, not all habits
- **Dhikr counter**: lives inside Habit Detail, not a separate screen

### iOS (SwiftUI + MVVM)
- `Features/*/Views` — presentation only
- `Features/*/ViewModels` — state ownership, @Observable, call services
- `Domain/` — pure models, business rules, repository protocols
- `Data/Local/` — SwiftData entities and repositories
- `Services/` — cross-cutting: AuthService, SyncCoordinator, NotificationScheduler
- `App/` — DependencyContainer, AppRouteState, AppEnvironment (config resolution)
- Concurrency: async/await, MainActor for UI

### Android (Compose + MVVM)
- `features/` — feature modules matching iOS
- `domain/` — models, repository interfaces, use cases
- `data/local/` — Room database + DAOs
- `data/remote/` — Supabase DTOs (generated from contracts)
- `core/` — OwnerScope, SessionUser, StreakCalculator, shared models
- `services/` — AuthService, SyncService, NotificationService
- `sync/` — WorkManager-based background sync
- ViewModel + StateFlow pattern; domain rules outside composables

### Supabase Backend
- Postgres 17 with RLS on all user data tables
- Auth: email OTP + Google OAuth; redirect schemes `adat://` and `sunnad://`
- Group RPCs: `create_group_with_owner()`, `join_group_by_code()` (case-insensitive codes)
- Composite foreign keys enforce habit ownership across linked tables
- Edge Functions: `send-nudge-push`, `delete-account`, `admin-quotes`, `translate-quote`, `waitlist-submit`, `launch-send`

## Key Constraints

- **i18n mandatory**: English (default) + Russian + Kazakh. No hardcoded UI strings. All labels/buttons/errors use translation keys.
- **RLS is the security layer**: never rely on client-side checks for authorization. Every user-data table needs RLS policies using `auth.uid()`.
- **No stack replacements**: don't swap SwiftData/Room/Supabase for alternatives without approval.
- **No new tabs or major flows** without approval.
- **Secrets**: never commit Supabase service role keys, JWT secrets, or APNS keys. CI runs secret scanning.
- **Contracts as source of truth**: Supabase migrations/RLS/RPCs define canonical backend behavior. Android DTOs are generated from these contracts.

## Environment Configuration

- **iOS**: Bundle Info.plist keys (`SunnadSupabaseURL`, `SunnadSupabaseAnonKey`, etc.) with debug fallbacks in `AppEnvironment`
- **Android**: BuildConfig fields from gradle properties, flavor-based overrides
- **Web**: `.env.local` (not committed), uses `NEXT_PUBLIC_*` and `SUNNAD_*` prefixed vars
