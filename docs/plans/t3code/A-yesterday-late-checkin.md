# Stream A — Yesterday (Late Check-In) fixes

## Goal

Fix the user-reported issues with the "Forgot yesterday?" late check-in flow **without changing
the product rule**: the recoverable window stays **00:00–03:59 local** (`LateCheckInPolicy`
default `graceHours: 4` in `sunnad-ios/sunnad-ios/Domain/Rules/DayContext.swift:3-9`). Do not
touch the window, the streak-break math, or `HabitMetricsCalculator`.

### User feedback being addressed (from Telegram, translated)

| Feedback | Root cause found |
|---|---|
| "yesterday не пропадает" / "долго респонс дает. Пропадает оч долго" (checking is slow, item disappears late or never) | No optimistic UI: tap awaits fetch + upsert + a full app reload incl. network sync before the row disappears; plus a silent no-op path when the clock passes 04:00 while the sheet is open |
| "сделать такой же UI в yesterday как в основном меню. Чтобы были кружки чекбоксы" (same UI as main menu, circle checkboxes) | Sheet uses plain `Button`+`Label` rows with a 2-step confirmation dialog — no checkboxes |
| "зикр UI нужно поменять" (dhikr UI) | **Out of scope here** — restyling the Habit Detail counter is stream C-adjacent polish; see note at bottom |

## Current code map (verify with Grep before editing)

| What | Where |
|---|---|
| `@Published lateCheckInCandidates` | `Features/Today/ViewModels/TodayViewModel.swift` (~:17) |
| Candidates resolved (only place) | `loadToday(...)` → `resolveLateCheckInCandidates(...)` (~:116-120, impl ~:367-400) |
| Sequential per-habit history fetch | `resolveLateCheckInCandidates` (~:376-382) |
| Record late check-in | `recordLateCheckIn(for:)` (~:144-193); **silent `false`** if window expired at tap (~:146-150) |
| Caller that triggers full reload | `App/AppRouteState.swift` (~:585-590): on success runs `loadTodayData()` (heavy: ~:1738-1772, reloadAllHabitsFromStorage ~:1833-1880) |
| Sheet UI (plain buttons, no checkbox) | `Features/Today/Views/TodayView.swift` sheet at ~:223-263; rows ~:225-233; confirmation dialog ~:241-254 |
| Prompt button | `TodayView.swift` ~:41-51, key `late_check_in.prompt` ("Forgot yesterday?" / RU "Забыли отметить вчера?") |
| Main-list row (the target look) | `Shared/Components/HabitRowView.swift` (~:3-80, checkbox ~:64-75); used at `TodayView.swift` ~:115-119 |
| Foreground/day-change reloads | `AppRouteState.swift` ~:1697-1713 |
| Candidates mirror into AppRouteState | `AppRouteState.swift` ~:1655-1659 (Combine) |
| Sheet wiring | `SunnadRootView.swift` ~:77 (passes candidates) and ~:84 (`onLateCheckIn` → `state.recordLateCheckIn`) |
| Existing tests | `sunnad-iosTests/ViewModels/TodayViewModelTests.swift` (~:200-260 record tests, ~:269-290 `lateCheckInIsUnavailableAtFourAM`), `sunnad-iosTests/Domain/HabitMetricsCalculatorTests.swift` (grace window) |

## Changes

### A1. Sheet rows use HabitRowView; checkbox = instant record

Replace the List of plain buttons + confirmation dialog with rows rendered via `HabitRowView`
(circle checkbox, icon, streak — same look as the main list).

- Checkbox tap → record immediately. **Delete the confirmation dialog** (~:241-254) — one tap,
  no "Record yesterday" step.
- Row body (non-checkbox) tap → no-op for now.
- Keep sheet title + Done button.

### A2. Optimistic tap (fixes "slow / doesn't disappear")

On checkbox tap, in `TodayViewModel`:

1. Immediately remove the habit from `lateCheckInCandidates` (list shrinks instantly; when the
   last row is removed, auto-dismiss the sheet).
2. Persist in the background via `recordLateCheckIn`.
3. On persistence **failure**: re-insert the candidate at its previous index + show an error
   toast (A5). Do not roll back silently.

Guard against double-tap: if the id is already removed, no-op.

### A3. Typed result + no silent window-closed no-op

Change `recordLateCheckIn(for:)` to return a result enum instead of `Bool`:

```swift
enum LateCheckInResult { case recorded, windowClosed, storageFailure }
```

- Window expired at tap time (`!context.isWithinLateCheckInWindow` with fresh `now()`):
  return `.windowClosed`, **clear all `lateCheckInCandidates`**, show the window-closed toast.
  Never return a bare `false` silently.
- `.recorded` and `.storageFailure` per A2/A4.
- Update the caller in `AppRouteState` (~:585-590) accordingly.

### A4. No full reload after recording

After a successful record, do **not** call `loadTodayData()` (it re-fetches everything, runs
sync, groups refresh — the source of the "slow response" feeling). Instead:

- `completionHistoryByHabitID` is already updated inside `recordLateCheckIn` — keep that.
- Recompute the affected habit's streak only (`StreakCalculator.streak(for:completions:context:)`
  — already used in `resolveLateCheckInCandidates`) and update that habit's `UIHabit` in the
  Today list + the AppRouteState mirror, because a yesterday completion can change today's
  displayed streak.
- Insights/Profile stay stale until the next natural reload (foreground / day change) —
  acceptable; note it in the summary.

### A5. Toasts (new strings, i18n required)

Reuse the closest existing in-app toast pattern (check how `GroupDetailView` shows the
reminder toast; if nothing fits Today, use a small transient overlay inside `TodayView`).
Two new keys in `Resources/Localizable.xcstrings` (EN + RU + KK):

| Key | EN | RU | KK |
|---|---|---|---|
| `late_check_in.window_closed` | Too late to check in for yesterday | Время для отметки за вчера истекло | Кешегі белгілеу уақыты өтті |
| `late_check_in.record_failed` | Couldn't save. Try again. | Не удалось сохранить. Попробуйте ещё раз. | Сақтау мүмкін болмады. Қайта көріңіз. |

Keep strings short (they sit near Dynamic Type limits; truncation-safe).

### A6. Sheet auto-eval on open

When the sheet appears (`task {}` on sheet content or `.onAppear`): if
`DayContext(now:calendar:timeZone:).isWithinLateCheckInWindow` is false → clear candidates via
the VM (add a small `clearStaleLateCheckInCandidates()` method, unit-testable) and dismiss the
sheet. Prevents a stale sheet after 04:00.

### A7. Parallel history fetch

In `resolveLateCheckInCandidates`, replace the sequential per-habit
`fetchCompletions` loop with a bounded `withTaskGroup` (≈8 concurrent). Preserve candidate
order (habit order). Keep the `preloadedHistories` fast-path.

## Explicit non-goals

- Window/grace-hours semantics: unchanged.
- `HabitMetricsCalculator` / streak-break timing: unchanged (tests exist — don't touch).
- Dhikr UI restyle (feedback "зикр UI нужно поменять"): **separate follow-up** (Habit Detail
  `DhikrCounterView` restyle only, per product decision). Do not bundle it here.
- No persisted "dismissed" flag — the prompt re-qualifies daily by design.

## Tests (add/adjust in `sunnad-iosTests/ViewModels/TodayViewModelTests.swift`)

1. Optimistic removal: with a fake repo that delays the upsert, candidates shrink immediately
   after the tap call starts (assert before awaiting completion).
2. Failure path: repo throws → candidate re-inserted at original index, result `.storageFailure`.
3. Window closed at tap → `.windowClosed`, candidates cleared.
4. `clearStaleLateCheckInCandidates()` clears only when outside window.
5. Streak recompute: after a successful record, the habit's UIHabit in the list reflects the
   new streak (use the existing grace-window fixtures from `HabitMetricsCalculatorTests`).
6. Existing tests keep passing (especially `lateCheckInIsUnavailableAtFourAM`).

## Acceptance criteria

- Tapping the checkbox removes the row visually instantly, even with slow storage.
- Recorded completion is unchanged in shape: `HabitCompletion(dayDate: yesterday,
  value: normalizedTargetCount, entrySource: .lateCheckIn)`.
- At 04:00+ with the sheet open: tap → toast + list cleared; no dead taps.
- Sheet with zero candidates auto-dismisses.
- Today list streaks update for the affected habit without a full reload.
- Sheet rows look like the main list (circle checkboxes).
- All new strings present in EN/RU/KK.
- Unit tests green via the README test command.

## Commit

```
today: make late check-in optimistic and match main list UI

- yesterday sheet rows use HabitRowView circle checkboxes, one-tap record
- optimistic candidate removal with rollback + toast on failure
- typed result replaces silent no-op when the 0-4AM window closes
- skip full reload after recording; recompute affected streak only
- parallel history fetch when resolving candidates
```
