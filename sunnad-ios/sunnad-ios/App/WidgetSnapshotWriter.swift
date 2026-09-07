import Foundation
import WidgetKit

@MainActor
final class WidgetSnapshotWriter {
    private let store: WidgetSharedStore?
    private var writeTask: Task<Void, Never>?
    private let debounceNanoseconds: UInt64
    private let calendar: Calendar
    private let timeZone: TimeZone

    init(
        store: WidgetSharedStore? = nil,
        debounceNanoseconds: UInt64 = 250_000_000,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) {
        self.store = store ?? WidgetSharedStore.makeShared()
        self.debounceNanoseconds = debounceNanoseconds
        self.calendar = calendar
        self.timeZone = timeZone
    }

    func writeFromApp(habits: [UIHabit], groups: [UIGroup]) {
        guard let store else { return }
        let snapshot = Self.makeSnapshot(
            habits: habits,
            groups: groups,
            previousSnapshot: store.readSnapshot(),
            calendar: calendar,
            timeZone: timeZone
        )
        writeTask?.cancel()
        writeTask = Task { [store, debounceNanoseconds] in
            try? await Task.sleep(nanoseconds: debounceNanoseconds)
            guard !Task.isCancelled else { return }
            // Widget taps recorded since this write was scheduled must not be
            // clobbered by the app's rebuilt snapshot.
            let pending = store.readPending()
            let merged = Self.applying(pending: pending, to: snapshot, store: store)
            store.writeSnapshot(merged)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Replays pending widget changes onto `snapshot` (oldest first), mirroring
    /// the app's replay semantics: a widget toggle only completes a habit and a
    /// widget increment only applies below target.
    static func applying(
        pending: [PendingChange],
        to snapshot: TodaySnapshot,
        store: WidgetSharedStore
    ) -> TodaySnapshot {
        var merged = snapshot
        let dayKey = merged.dateKey
        var applied = false
        for change in PendingChangeQueue.replayOrder(pending) {
            let habitID: UUID
            switch change.kind {
            case .toggleHabit(let id): habitID = id
            case .dhikrIncrement(let id): habitID = id
            }
            guard let index = merged.habits.firstIndex(where: { $0.id == habitID }) else {
                continue
            }
            switch change.kind {
            case .toggleHabit:
                guard !merged.habits[index].completedToday else { continue }
                if merged.habits[index].isDhikr {
                    merged.habits[index].dhikrCount = max(merged.habits[index].targetCount, 1)
                }
                merged.habits[index].completedToday = true
                applied = true
            case .dhikrIncrement:
                let target = max(merged.habits[index].targetCount, 1)
                guard merged.habits[index].dhikrCount < target else { continue }
                merged.habits[index].dhikrCount = min(merged.habits[index].dhikrCount + 1, target)
                merged.habits[index].completedToday = merged.habits[index].dhikrCount >= target
                applied = true
            }
        }
        guard let stored = store.readSnapshot(), stored.dateKey == dayKey else {
            return applied ? merged : snapshot
        }
        // Preserve widget-side state for fields the app view doesn't own.
        merged.failedNudgeMemberIDs = stored.failedNudgeMemberIDs
        merged.sessionExpired = stored.sessionExpired
        return applied ? merged : snapshot
    }

    static func makeSnapshot(
        habits: [UIHabit],
        groups: [UIGroup],
        previousSnapshot: TodaySnapshot?,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> TodaySnapshot {
        let context = DayContext(now: Date(), calendar: calendar, timeZone: timeZone)
        let dateKey = context.dayKey(for: context.today)

        var habitSnapshots: [HabitSnapshot] = []
        habitSnapshots.reserveCapacity(habits.count)
        for habit in habits {
            habitSnapshots.append(
                HabitSnapshot(
                    id: habit.id,
                    title: habit.displayTitle,
                    icon: habit.iconSystemName,
                    isDhikr: habit.isDhikr,
                    dhikrCount: habit.dhikrCount,
                    targetCount: habit.dhikrTarget,
                    completedToday: habit.completedToday,
                    streak: max(0, habit.streak)
                )
            )
        }

        let previousSentNudgeMemberIDs = previousSnapshot?.dateKey == dateKey
            ? (previousSnapshot?.groups ?? [])
            : []

        var groupSnapshots: [GroupSnapshot] = []
        groupSnapshots.reserveCapacity(groups.count)
        for group in groups {
            var memberSnapshots: [MemberSnapshot] = []
            memberSnapshots.reserveCapacity(group.members.count)
            for member in group.members {
                let habitMinis = member.sharedHabits
                    .filter(\.dueToday)
                    .map { shared in
                        HabitMini(
                            habitID: shared.habitID,
                            title: shared.habitTitle,
                            completed: shared.completedToday
                        )
                    }
                memberSnapshots.append(
                    MemberSnapshot(
                        id: member.userID,
                        name: member.name,
                        avatarPath: member.avatarURL?.absoluteString,
                        habits: habitMinis
                    )
                )
            }
            let carriedSentNudges = previousSentNudgeMemberIDs.first(where: { $0.id == group.id })?.sentNudgeMemberIDs ?? []
            groupSnapshots.append(
                GroupSnapshot(
                    id: group.id,
                    name: group.name,
                    members: memberSnapshots,
                    sentNudgeMemberIDs: carriedSentNudges
                )
            )
        }

        let previousSessionExpired = previousSnapshot?.dateKey == dateKey ? previousSnapshot?.sessionExpired : nil

        return TodaySnapshot(
            dateKey: dateKey,
            timeZoneID: timeZone.identifier,
            habits: habitSnapshots,
            groups: groupSnapshots,
            sessionExpired: previousSessionExpired
        )
    }
}
