# Supabase Schema Audit — Stage 4

## Scope
This audit covers the Stage-4 hardening migration:
- contract-stable group RPCs
- ownership integrity via composite FKs
- schedule and sync safety constraints
- index coverage for common query and RLS paths

## Public interfaces changed
1. `public.create_group_with_owner(group_name text) returns uuid`
2. `public.join_group_by_code(invite_code text)` now normalizes (`trim + upper`) invite codes

## Table and constraint audit
| Table | New / changed constraints | Why |
|---|---|---|
| `public.habits` | `habits_schedule_supported` (`daily` or `weekly`) | Prevent unsupported schedule values from entering DB state |
| `public.habits` | unique index on `(user_id, id)` | Enables ownership-safe composite foreign keys |
| `public.habit_completions` | FK `(user_id, habit_id)` -> `habits(user_id, id)` | Enforces completion ownership against the habit owner |
| `public.group_shared_habits` | FK `(user_id, habit_id)` -> `habits(user_id, id)` | Prevents sharing rows from referencing a habit under mismatched owner |
| `public.group_members` | `updated_at` + update trigger | Enables incremental sync reads by update timestamp |
| `public.saved_quotes` | `updated_at` + update trigger | Enables incremental sync reads by update timestamp |

## RLS/policy compatibility check
No policy definitions were removed. Stage-4 constraints harden data integrity underneath existing RLS rules:
- Group create/join remains authenticated and membership-based.
- Shared habit visibility remains group-membership scoped.
- Nudge insertion rules remain sender/member/shared-habit validated.

## Index audit (added)
| Index | Purpose |
|---|---|
| `group_members_user_group_idx` | Faster group lookup from `user_id` and membership joins |
| `group_members_user_updated_idx` | Incremental sync pulls by user + updated timestamp |
| `group_shared_habits_group_shared_user_habit_idx` | RLS and group shared-habit reads with shared flag |
| `group_shared_habits_user_habit_group_idx` | Ownership and per-habit sharing lookups |
| `habit_completions_user_habit_updated_idx` | Sync and history pulls for user-habit streams |
| `saved_quotes_user_updated_idx` | Incremental sync window scans for saved quotes |
| `nudges_sender_day_idx` | Sender/day anti-spam and audit queries |

## Stage-4 smoke verification
Use the dedicated script after `supabase db reset`:

```bash
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/stage4_smoke.sql
```

Covered scenarios:
1. create group by authenticated owner RPC
2. join by mixed-case invite code
3. shared-habit visibility through membership
4. nudge one-per-day uniqueness behavior
