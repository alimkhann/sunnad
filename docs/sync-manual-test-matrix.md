# Sync Manual Test Matrix (Stage 7)

## Goal
Validate outbox push/pull behavior, foreground/background triggers, and two-device convergence for signed-in users while keeping guest mode offline-only.

## Preconditions
- Same Supabase environment configured on both devices (or simulator + real device).
- Authenticated user account available.
- Devices can be independently toggled offline/online.

## 1) Outbox push (single device)
1. Sign in.
2. Create a habit, toggle completion, save a quote.
3. Confirm local UI updates immediately (offline-first).
4. Reopen app with network enabled.
5. Verify remote rows are present (`habits`, `habit_completions`, `saved_quotes`).

## 2) Pull merge (single device)
1. Change a habit name/order from another client (or SQL editor).
2. Bring app to foreground.
3. Verify local data updates after sync cycle.
4. Confirm no crash and no duplicate rows.

## 3) Two-device convergence (LWW)
1. On device A, edit habit name to `A1` while online.
2. On device B, go offline and edit same habit name to `B1`.
3. Bring B online later and foreground app.
4. Verify both devices converge to the latest `updated_at` value.

## 4) Completion window behavior
1. Insert/fetch completion records older than 40 days and within 40 days.
2. Foreground sync.
3. Verify pull only tracks the rolling 40-day completion window.

## 5) Group snapshot pull
1. Join/create group and update sharing.
2. Foreground sync.
3. Verify local sync snapshot entities are populated for:
- `groups`
- `group_members`
- `group_shared_habits`

## 6) Background refresh smoke
1. Sign in and send app to background.
2. Wait for BG refresh window.
3. Check logs for `sync_bg_schedule` and `sync_cycle trigger=background`.

## 7) Guest isolation
1. Sign out to guest.
2. Modify habits/completions offline.
3. Verify no Supabase traffic is required.
4. Sign in again and confirm promotion + sync succeeds.

## 8) Failure and retry
1. Disconnect network and perform habit/completion updates while signed in.
2. Reconnect network and foreground app.
3. Verify pending outbox events flush successfully.
4. Verify retries survive app relaunch.
