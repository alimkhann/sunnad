# Stream C — Widgets (home screen + lock screen)

## Goal

Ship a widget-extension target with five widgets, offline-first, sharing state with the app via
an App Group. Per product decision, all widgets ship together in this stream. Dhikr stays a
Habit-Detail feature in the app (see C6 for the related polish: restyle the detail counter only).

Constraints recap (from AGENTS.md): exactly 3 tabs in the app (widgets don't change that),
offline-first, no hardcoded strings (EN/RU/KK), system appearance only (no glass/material in
widget content), no new dependencies.

## C0. Project setup

### C0.1 New extension target

- Add target `sunnad-iosWidget` (Widget Extension, WidgetKit, Swift) to
  `sunnad-ios/sunnad-ios.xcodeproj`.
- Bundle IDs per configuration, prefixed by the app's bundle ID (follow the existing
  `SUNNAD_*` build-settings pattern in `project.pbxproj`):
  - Debug: `com.arystan.almasuly.sunnad.dev.widgets`
  - Release: `com.arystan.almasuly.sunnad.widgets`
  - Local: `com.arystan.almasuly.sunnad.local.widgets`
- Deployment target: iOS 17.0 (interactive widgets require 17; app is 17.6 — fine).
- Widget extension is embedded in all app configurations.

### C0.2 App Groups (entitlements)

App Group IDs per configuration (variable substitution via build settings, e.g. `SUNNAD_APP_GROUP_ID`):

| Config | App Group |
|---|---|
| Debug | `group.com.arystan.almasuly.sunnad.dev` |
| Release | `group.com.arystan.almasuly.sunnad` |
| Local | `group.com.arystan.almasuly.sunnad.local` |

- Add the App Group entitlement to **both** the app target and the widget target
  (app currently has `sunnad-ios/sunnad-ios/sunnad-ios.entitlements` with aps-environment +
  Sign in with Apple; create/extend per-config as needed — entitlements files are per-target,
  so use build-settings substitution or one entitlements file per configuration).
- Try automatic signing first: `xcodebuild -allowProvisioningUpdates`. If the App Group
  capability can't be provisioned automatically, ask the human to sign in to the Apple
  Developer portal / App Store Connect.

### C0.3 Shared code

Create shared source files included in **both** app and widget targets (target membership, no
new framework):

```
sunnad-ios/sunnad-ios/Shared/Widgets/WidgetSharedStore.swift   (app-group container access, atomic writes)
sunnad-ios/sunnad-ios/Shared/Widgets/WidgetSnapshot.swift      (TodaySnapshot model)
sunnad-ios/sunnad-ios/Shared/Widgets/PendingChange.swift       (queue model + replay types)
```

Widget UI files live in `sunnad-ios/sunnad-iosWidget/`.

- Localization: add the existing
  `sunnad-ios/sunnad-ios/Resources/Localizable.xcstrings` to the widget target's resources so
  `L10n.t` keys resolve in the extension (single source of truth, EN/RU/KK).
- Shared UI: reuse design tokens where possible; do not pull SwiftUI app views into the
  widget beyond `HabitRowView`-style visuals re-implemented for widget scale.

## C1. Data plane

### C1.1 `TodaySnapshot` (Codable JSON, versioned)

```swift
struct TodaySnapshot: Codable, Sendable {
  var version: Int            // bump on schema change; decoder tolerates older versions (ignore+wait for rewrite)
  var dateKey: String         // "YYYY-MM-DD" local day the snapshot belongs to
  var timeZoneID: String
  var habits: [HabitSnapshot]        // today's habits only, in user order
  var groups: [GroupSnapshot]        // last-refreshed group summaries
  var completedCount: Int { ... }    // derived
}
struct HabitSnapshot: Codable, Sendable {
  var id: UUID; var title: String; var icon: String
  var isDhikr: Bool; var dhikrCount: Int; var targetCount: Int
  var completedToday: Bool; var streak: Int
}
struct GroupSnapshot: Codable, Sendable {
  var id: UUID; var name: String
  var members: [MemberSnapshot]      // id, name, avatarPath?, per-shared-habit [HabitMini{habitID,title,completed}]
  var sentNudgeMemberIDs: [UUID]     // for button state
}
```

Writer: `WidgetSnapshotWriter` — builds the snapshot from app state and writes
`snapshot.json` + `pending.json` into the App Group container. **Atomic writes**: write temp
file + rename (two processes write this container). Debounce 250ms.

Hook points (all in `AppRouteState` — call writer then `WidgetCenter.shared.reloadAllTimelines()`):

- after every habit toggle commit (incl. the debounced reload ~:1727-1736)
- after late check-in (stream A result path)
- after dhikr increment (`handleDhikrCounterIncrement` ~:600-609)
- after groups refresh / group state change
- after sign-in, sign-out, account restore
- on willEnterForeground reload and `NSCalendarDayChanged` (~:1697-1713) — snapshot is day-scoped;
  on day change the widget shows the new day's list only after the app recomputes it. Until the
  next app run, a stale-day snapshot shows the progress ring/date mismatch state (C5).

### C1.2 Session material for the Groups widget

Separate keys in the **App Group UserDefaults** (MVP decision; keychain upgrade deferred):

- `widget.session.supabaseURL`, `widget.session.anonKey`, `widget.session.accessToken`,
  `widget.session.userID`

Set on sign-in/restore, cleared on sign-out. Security note: same-app-group containers are only
readable by this app's own targets; document the keychain upgrade path in a code comment header.

### C1.3 Pending-change queue + replay (widget → app)

Widget intents cannot write the app's SwiftData store (app container). Instead:

1. Intent appends `PendingChange {id: UUID, kind: .toggleHabit(habitID) | .dhikrIncrement(habitID), createdAt}`
   to `pending.json` (append-only until replay).
2. Intent also **optimistically mutates the snapshot** (flip `completedToday`, `dhikrCount += 1`)
   and posts `WidgetCenter.reloadAllTimelines()` so the widget UI updates instantly.
3. Intent signals the app: post a Darwin notification (e.g.
   `CFNotificationCenterPostNotification` with name `"adat.widgetstore.changed"`). The app
   observes it (and also replays on every willEnterForeground).
4. App replay `replayPendingWidgetChanges()` in `AppRouteState`:
   - For each pending change (dedupe by id, apply oldest first):
     - `.toggleHabit`: only if the habit is on today's list and not already completed → run the
       **same commit path as the in-app toggle** (persistence + streak recompute + reminder
       rescheduling / suppression via the existing reminder sync), then remove from queue.
       If already completed or habit no longer due → drop (idempotent).
     - `.dhikrIncrement`: reuse the existing dhikr increment path (~:600-609), respecting the
       target cap (do not exceed `normalizedTargetCount`).
   - After replay: rewrite `snapshot.json` from app state + `reloadAllTimelines()`.
   - Replay must be serialized (a simple in-memory task queue) and must not run concurrently
     with a user-driven toggle of the same habit — route through the same actor.

This keeps the app as source of truth and reuses all domain rules (reminders, streaks, sync).

## C2. Widgets

Bundle all in `SunnadWidgetsBundle` (WidgetKit `WidgetBundle`). All widgets read the snapshot;
**no widget blocks on network except the nudge send (C2.4)**. Timeline policy `.never` + explicit
`WidgetCenter.reloadAllTimelines()` from the app/intents; Groups widget additionally uses
`.after(Date + 30-60min)` so stale content self-flags.

### C2.1 TodayChecklistWidget (systemMedium, systemLarge)

- Rows of today's habits (medium ≤5, large ≤8, then "…" overflow row), each with a circle
  checkbox (`circle` / `checkmark.circle.fill`), icon, title, small streak flame.
- Checkbox = `ToggleHabitIntent(habitID:)` (interactive AppIntent, iOS 17).
- Footer: "X/Y" (L10n key `widgets.today.progress`, format `"{0}/{1}"`).
- Tapping a row title deep-links into the app (Today tab) via widget URL.
- Empty state: "No habits today" (L10n `widgets.today.empty`).

### C2.2 QuickToggleWidget (systemSmall + accessoryCircular)

- Toggles a single habit. Default habit = first uncompleted today (then first habit); the user
  can pin a specific habit via intent parameter (`@Parameter` with dynamic options provider
  listing today's habits).
- Lock-screen circular accessory shows check state.

### C2.3 ProgressWidget (systemSmall + accessoryRectangular)

- Progress ring X/Y + streak ("🔥 12" — no emoji in code strings; use SF Symbol `flame`).
- Date-aware: shows "up to date as of" nothing — if `snapshot.dateKey != today` per device
  time, render a muted "Open Sunnad to refresh" state (L10n `widgets.stale`) instead of wrong
  progress.

### C2.4 GroupsWidget (systemMedium, systemLarge)

- Per member row: avatar (from snapshot path), name, completed/total for shared habits today,
  tiny per-habit dots.
- **Remind button per member** (`bell` SF Symbol) → `SendNudgeIntent(groupID:memberID:habitID:)`:
  - Requires session keys present; if absent/401 → write `sessionExpired` flag to snapshot,
    button renders "Open Sunnad" deep-link state (L10n `widgets.groups.signin`).
  - Otherwise: `POST {supabaseURL}/functions/v1/send-nudge-push` with headers
    `Authorization: Bearer <accessToken>`, `apikey: <anonKey>`, body
    `{"group_id":…, "to_user_id":…, "habit_id":…}` — the exact contract the app uses
    (`SupabaseGroupsRepository.invokeNudgeFunction`). Timeout 10s; on success (response
    `delivered == true`) mark member in `sentNudgeMemberIDs`, disable the button for the local
    day (server idempotency protects), reload. On failure: transient "Couldn't send" state,
    do not block the widget.
  - Client-side rate-limit mirror: one send per member per local day (matches server
    `reserve_group_nudge`), so the button state is predictable.
- Widget body long-press/tap → deep link to that group's detail in the app (URL scheme —
  follow the app's existing deep-link/router; if none exists for group detail, deep link to
  the Groups tab as MVP and note it).
- Offline/never-refreshed state: show last snapshot + stale flag.

### C2.5 DhikrCounterWidget (systemSmall)

- Chosen dhikr habit (intent parameter with dynamic options: dhikr habits only).
- Shows circular progress (count/target), count label; tap = `IncrementDhikrIntent(habitID:)`
  (snapshot +1, queue, reload). At target, tap is no-op and ring shows complete.
- Tapping the title deep-links to the app (Habit detail).

### C2.6 Related polish (in-app, small)

Dhikr Habit-Detail counter (`Features/Habits/Views/DhikrCounterView.swift`) restyle per
feedback "зикр UI нужно поменять" — **restyle only, no behavior change**: larger tap target on
the increment button, clearer count/target display, cleaner phrase picker. Keep the
Details/Counter segmented structure in `HabitDetailSheetView` intact.

## C3. i18n

New keys (EN/RU/KK) — all via `Localizable.xcstrings`, used by widget + deep-link states:

| Key | EN | RU | KK |
|---|---|---|---|
| `widgets.today.progress` | %1$@/%2$@ done | %1$@/%2$@ выполнено | %1$@/%2$@ орындалды |
| `widgets.today.empty` | No habits today | Сегодня нет привычек | Бүгін дағы әдет жоқ |
| `widgets.stale` | Open Sunnad to refresh | Откройте Sunnad, чтобы обновить | Жаңарту үшін Sunnad ашыңыз |
| `widgets.groups.signin` | Sign in to remind | Войдите, чтобы напомнить | Еске салу үшін кіріңіз |
| `widgets.groups.remind` | Remind | Напомнить | Еске салу |
| `widgets.groups.sent` | Sent | Отправлено | Жіберілді |
| `widgets.groups.send_failed` | Couldn't send | Не удалось отправить | Жіберу мүмкін болмады |

(Existing keys for habit titles etc. come from the snapshot — titles are already localized by
the app.)

## C4. Concurrency & correctness notes

- Snapshot encode/decode must be versioned and forward-compatible; never crash on old files.
- Atomic writes (temp+rename) for both `snapshot.json` and `pending.json`; all access through
  `WidgetSharedStore` (single API for both processes).
- AppIntents: mark heavy work with progress; keep `perform()` fast (<1s) — it writes files and
  reloads timelines only.
- App replay runs on the same actor as habit mutations to avoid double-writes.
- `WidgetCenter` calls from the app are safe; from intents they reload that widget's timeline.

## C5. Tests

Unit (in `sunnad-iosTests`, files must not require widget target):

1. Snapshot encode → decode round-trip incl. version bump tolerance.
2. `PendingChange` queue: append, dedupe by id, drop-when-already-applied logic (pure funcs).
3. Replay logic: toggle for a habit not due today is dropped; toggle for completed habit is
   dropped; valid toggle persists (fake repos) and reschedules reminders (fake scheduler
   records suppression).
4. Groups nudge client: request body/headers correct; `delivered` parsing; failure → no state
   corruption (fake URLSession).

Manual on simulator (document results):

- Add each widget; checklist mirrors app state; toggle from widget → checkbox flips instantly;
  open app → state matches; the toggled habit's local reminder is suppressed (verify via the
  existing debug pending-reminder count, `SunnadRootView` ~:169-172).
- Dhikr widget increments; Habit Detail count matches; target cap respected.
- Groups widget: sign-in → Remind → (with B fixed) recipient gets push; button becomes "Sent";
  sign-out → sign-in prompt state.
- Lock-screen accessory variants render.
- RU and KK locales: strings fit (no truncation ugliness at default Dynamic Type).

## Acceptance criteria

- Widget target builds for all 3 configurations; app + widget both build via the README commands.
- All 5 widgets appear in the gallery with correct sizes and localized strings.
- Widget→app toggle/dhikr replay is idempotent and never double-counts.
- Widgets work fully offline (snapshot render); no widget waits on network at render time
  (nudge send is the only network call, and it is user-initiated).
- App-side reminder scheduling remains correct after widget-driven completions.
- No secrets in the App Group container beyond the session token MVP decision documented above.

## Commit

```
widgets: home-screen + lock-screen widget suite

- widget extension target (5 widgets): today checklist, quick toggle,
  progress/streak, groups with tap-to-remind, dhikr counter
- App Group snapshot store (versioned, atomic) + pending-change queue
  replayed by the app on foreground, reusing domain rules + reminder sync
- interactive intents: toggle habit, increment dhikr, send nudge
- shared Localizable.xcstrings for widget strings (EN/RU/KK)
- restyle dhikr detail counter (tap target, count display)
```
