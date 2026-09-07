import Foundation
import SwiftData
import Testing
@testable import sunnad_ios

@MainActor
struct WidgetStoreTests {
    // MARK: - Snapshot

    @Test
    func snapshotRoundTripPreservesFields() throws {
        let (store, _) = try makeStore()
        let snapshot = makeSnapshot()

        #expect(store.writeSnapshot(snapshot))

        let decoded = try #require(store.readSnapshot())
        #expect(decoded == snapshot)
    }

    @Test
    func olderSnapshotVersionStillDecodes() throws {
        let (store, container) = try makeStore()
        let snapshot = makeSnapshot()

        try writeRawSnapshot(snapshot, version: 0, to: container)

        let decoded = try #require(store.readSnapshot())
        #expect(decoded.dateKey == snapshot.dateKey)
        #expect(decoded.habits == snapshot.habits)
        #expect(decoded.groups == snapshot.groups)
        #expect(decoded.version == TodaySnapshot.currentVersion)
    }

    @Test
    func futureSnapshotVersionIsIgnoredUntilRewrite() throws {
        let (store, container) = try makeStore()
        let snapshot = makeSnapshot()

        try writeRawSnapshot(snapshot, version: TodaySnapshot.currentVersion + 1, to: container)

        #expect(store.readSnapshot() == nil)
    }

    @Test
    func snapshotWriterCarriesSentNudgesWithinSameDay() {
        let groupID = UUID()
        let memberID = UUID()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        let todayKey = String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
        let previous = TodaySnapshot(
            dateKey: todayKey,
            timeZoneID: "UTC",
            habits: [],
            groups: [
                GroupSnapshot(
                    id: groupID,
                    name: "Family",
                    members: [],
                    sentNudgeMemberIDs: [memberID]
                )
            ]
        )
        let next = WidgetSnapshotWriter.makeSnapshot(
            habits: [],
            groups: [
                UIGroup(id: groupID, name: "Family", code: "CODE", members: [], sharedHabitIDs: [])
            ],
            previousSnapshot: previous
        )

        #expect(next.dateKey == previous.dateKey)
        #expect(next.groups.first?.sentNudgeMemberIDs == [memberID])
    }

    // MARK: - Pending queue

    @Test
    func pendingQueueDedupesByIdAndReplaysOldestFirst() throws {
        let first = PendingChange(kind: .toggleHabit(UUID()), createdAt: Date(timeIntervalSince1970: 100))
        let second = PendingChange(kind: .dhikrIncrement(UUID()), createdAt: Date(timeIntervalSince1970: 50))

        var queue = PendingChangeQueue.appending(first, to: [])
        queue = PendingChangeQueue.appending(second, to: queue)
        queue = PendingChangeQueue.appending(first, to: queue)

        #expect(queue.map(\.id) == [first.id, second.id])
        #expect(PendingChangeQueue.replayOrder(queue).map(\.id) == [second.id, first.id])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([PendingChange].self, from: encoder.encode(queue))
        #expect(decoded == queue)
    }

    @Test
    func pendingChangeRoundTripsThroughStoreFile() throws {
        let (store, _) = try makeStore()
        let toggle = PendingChange(kind: .toggleHabit(UUID()))
        let dhikr = PendingChange(kind: .dhikrIncrement(UUID()))

        store.appendPending(toggle)
        store.appendPending(dhikr)
        store.appendPending(toggle)

        #expect(store.readPending().map(\.id) == [toggle.id, dhikr.id])

        store.replacePending([])
        #expect(store.readPending().isEmpty)
    }

    @Test
    func storeFallsBackToUserDefaultsWhenContainerUnavailable() throws {
        let defaults = UserDefaults(suiteName: "widget-tests-\(UUID().uuidString)")!
        let store = WidgetSharedStore(userDefaults: defaults, containerURL: nil)
        let snapshot = makeSnapshot()

        #expect(store.writeSnapshot(snapshot))
        #expect(store.readSnapshot() == snapshot)

        let change = PendingChange(kind: .toggleHabit(UUID()))
        #expect(store.appendPending(change))
        #expect(store.readPending().map(\.id) == [change.id])
    }

    // MARK: - Replay through AppRouteState

    @Test
    func widgetReplayTogglesHabitAndIncrementsDhikr() async throws {
        let binaryHabit = Habit(name: "Read", icon: "book", type: .binary, schedule: .daily)
        let dhikrHabit = Habit(name: "Dhikr", icon: "circle", type: .dhikr, targetCount: 33, schedule: .daily)
        let container = try makeInMemoryContainer()
        let ownerScope = makeTestOwnerScopeResolver()
        let habitsRepo = HabitsLocalRepository(
            modelContext: container.mainContext,
            logger: TestLogger(),
            ownerScopeProvider: ownerScope
        )
        try await habitsRepo.saveHabit(binaryHabit)
        try await habitsRepo.saveHabit(dhikrHabit)

        let (store, _) = try makeStore()
        store.replacePending([
            PendingChange(kind: .toggleHabit(binaryHabit.id)),
            PendingChange(kind: .dhikrIncrement(dhikrHabit.id)),
        ])

        let dependencies = DependencyContainer(modelContainer: container)
        let state = AppRouteState(dependencies: dependencies, widgetStore: store)
        _ = await waitUntil { !state.todayHabits.isEmpty }

        state.replayPendingWidgetChanges()

        _ = await waitUntil {
            guard let binary = state.todayHabits.first(where: { $0.id == binaryHabit.id }),
                  let dhikr = state.todayHabits.first(where: { $0.id == dhikrHabit.id }) else {
                return false
            }
            return binary.completedToday && dhikr.dhikrCount == 1
        }

        #expect(store.readPending().isEmpty)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let completionsRepo = CompletionsLocalRepository(
            modelContext: container.mainContext,
            logger: TestLogger(),
            ownerScopeProvider: ownerScope
        )
        let today = Date()
        let binaryCompletion = try #require(
            await completionsRepo.fetchCompletion(habitID: binaryHabit.id, on: today, calendar: calendar, timeZone: .current)
        )
        #expect(binaryCompletion.value == 1)
        let dhikrCompletion = try #require(
            await completionsRepo.fetchCompletion(habitID: dhikrHabit.id, on: today, calendar: calendar, timeZone: .current)
        )
        #expect(dhikrCompletion.value == 1)
    }

    @Test
    func widgetReplayDropsCompletedAndNotDueChanges() async throws {
        let completedHabit = Habit(name: "Done", icon: "check", type: .binary, schedule: .daily)
        let todayWeekday = Weekday.isoWeekday(for: Date())
        let notDueWeekday = Weekday.allCases.first { $0 != todayWeekday } ?? .monday
        let notDueHabit = Habit(name: "Weekly", icon: "calendar", type: .binary, schedule: .weekly([notDueWeekday]))

        let container = try makeInMemoryContainer()
        let ownerScope = makeTestOwnerScopeResolver()
        let habitsRepo = HabitsLocalRepository(
            modelContext: container.mainContext,
            logger: TestLogger(),
            ownerScopeProvider: ownerScope
        )
        try await habitsRepo.saveHabit(completedHabit)
        try await habitsRepo.saveHabit(notDueHabit)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let completionsRepo = CompletionsLocalRepository(
            modelContext: container.mainContext,
            logger: TestLogger(),
            ownerScopeProvider: ownerScope
        )
        let today = Date()
        try await completionsRepo.upsertCompletion(
            HabitCompletion(habitID: completedHabit.id, dayDate: today, value: 1),
            calendar: calendar,
            timeZone: .current
        )

        let (store, _) = try makeStore()
        store.replacePending([
            PendingChange(kind: .toggleHabit(completedHabit.id)),
            PendingChange(kind: .toggleHabit(notDueHabit.id)),
        ])

        let dependencies = DependencyContainer(modelContainer: container)
        let state = AppRouteState(dependencies: dependencies, widgetStore: store)
        _ = await waitUntil { !state.todayHabits.isEmpty }

        state.replayPendingWidgetChanges()
        _ = await waitUntil { store.readPending().isEmpty }

        let completedAfter = try #require(
            await completionsRepo.fetchCompletion(habitID: completedHabit.id, on: today, calendar: calendar, timeZone: .current)
        )
        #expect(completedAfter.value == 1)
        let notDueCompletion = try await completionsRepo.fetchCompletion(
            habitID: notDueHabit.id,
            on: today,
            calendar: calendar,
            timeZone: .current
        )
        #expect(notDueCompletion == nil)
    }

    // MARK: - Helpers

    private func makeStore() throws -> (WidgetSharedStore, URL) {
        let container = FileManager.default.temporaryDirectory
            .appendingPathComponent("widget-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let defaults = UserDefaults(suiteName: "widget-tests-\(UUID().uuidString)")!
        return (WidgetSharedStore(userDefaults: defaults, containerURL: container), container)
    }

    private func makeSnapshot() -> TodaySnapshot {
        TodaySnapshot(
            dateKey: "2026-09-07",
            timeZoneID: "Asia/Almaty",
            habits: [
                HabitSnapshot(
                    id: UUID(),
                    title: "Read",
                    icon: "book.fill",
                    isDhikr: false,
                    dhikrCount: 0,
                    targetCount: 0,
                    completedToday: true,
                    streak: 3
                )
            ],
            groups: [
                GroupSnapshot(
                    id: UUID(),
                    name: "Family",
                    members: [
                        MemberSnapshot(
                            id: UUID(),
                            name: "Ali",
                            avatarPath: nil,
                            habits: [HabitMini(habitID: UUID(), title: "Quran", completed: false)]
                        )
                    ],
                    sentNudgeMemberIDs: []
                )
            ]
        )
    }

    private func writeRawSnapshot(_ snapshot: TodaySnapshot, version: Int, to container: URL) throws {
        let encoder = JSONEncoder()
        var json = try JSONSerialization.jsonObject(with: encoder.encode(snapshot)) as! [String: Any]
        json["version"] = version
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: container.appendingPathComponent("widget-snapshot.json"))
    }

    private func waitUntil(_ condition: @MainActor () -> Bool, timeout: TimeInterval = 10) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return condition()
    }
}
