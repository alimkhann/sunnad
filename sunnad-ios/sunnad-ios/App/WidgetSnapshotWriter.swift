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
            store.writeSnapshot(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
        }
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
