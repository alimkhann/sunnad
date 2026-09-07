import AppIntents
import Foundation
import WidgetKit

struct ToggleHabitIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("widgets.intents.toggle.title")

    @Parameter(title: LocalizedStringResource("widgets.intents.param.habit"))
    var habitID: String

    init() {}

    init(habitID: String) {
        self.habitID = habitID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let store = WidgetSharedStore.makeShared() else {
            return .result()
        }
        let dayKey = WidgetSupport.todayDayKey()
        if var snapshot = store.readSnapshot(), snapshot.dateKey == dayKey,
           let index = snapshot.habits.firstIndex(where: { $0.id.uuidString == habitID }) {
            if snapshot.habits[index].isDhikr {
                if snapshot.habits[index].completedToday {
                    snapshot.habits[index].dhikrCount = 0
                    snapshot.habits[index].completedToday = false
                } else {
                    snapshot.habits[index].dhikrCount = max(snapshot.habits[index].targetCount, 1)
                    snapshot.habits[index].completedToday = true
                }
            } else {
                snapshot.habits[index].completedToday.toggle()
            }
            store.writeSnapshot(snapshot)
        }
        if let uuid = UUID(uuidString: habitID) {
            store.appendPending(PendingChange(kind: .toggleHabit(uuid)))
        }
        WidgetCenter.shared.reloadAllTimelines()
        WidgetSupport.postStoreChanged()
        return .result()
    }
}

struct IncrementDhikrIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("widgets.intents.dhikr.title")

    @Parameter(title: LocalizedStringResource("widgets.intents.param.habit"))
    var habitID: String

    init() {}

    init(habitID: String) {
        self.habitID = habitID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let store = WidgetSharedStore.makeShared() else {
            return .result()
        }
        let dayKey = WidgetSupport.todayDayKey()
        if var snapshot = store.readSnapshot(), snapshot.dateKey == dayKey,
           let index = snapshot.habits.firstIndex(where: { $0.id.uuidString == habitID }) {
            let target = max(snapshot.habits[index].targetCount, 1)
            if snapshot.habits[index].dhikrCount < target {
                snapshot.habits[index].dhikrCount = min(snapshot.habits[index].dhikrCount + 1, target)
                snapshot.habits[index].completedToday = snapshot.habits[index].dhikrCount >= target
                store.writeSnapshot(snapshot)
                if let uuid = UUID(uuidString: habitID) {
                    store.appendPending(PendingChange(kind: .dhikrIncrement(uuid)))
                }
                WidgetCenter.shared.reloadAllTimelines()
                WidgetSupport.postStoreChanged()
            }
        }
        return .result()
    }
}

struct SendNudgeIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("widgets.intents.remind.title")

    @Parameter(title: LocalizedStringResource("widgets.intents.param.group"))
    var groupID: String

    @Parameter(title: LocalizedStringResource("widgets.intents.param.member"))
    var memberID: String

    @Parameter(title: LocalizedStringResource("widgets.intents.param.habit"))
    var habitID: String

    init() {}

    init(groupID: String, memberID: String, habitID: String) {
        self.groupID = groupID
        self.memberID = memberID
        self.habitID = habitID
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let store = WidgetSharedStore.makeShared() else {
            return .result(dialog: IntentDialog(LocalizedStringResource("widgets.groups.send_failed")))
        }
        guard var snapshot = store.readSnapshot() else {
            return .result(dialog: IntentDialog(LocalizedStringResource("widgets.stale")))
        }

        let dayKey = WidgetSupport.todayDayKey()
        guard snapshot.dateKey == dayKey else {
            return .result(dialog: IntentDialog(LocalizedStringResource("widgets.stale")))
        }
        guard let session = store.readSession() else {
            snapshot.sessionExpired = true
            store.writeSnapshot(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
            return .result(dialog: IntentDialog(LocalizedStringResource("widgets.groups.signin")))
        }

        guard let groupIndex = snapshot.groups.firstIndex(where: { $0.id.uuidString == groupID }),
              snapshot.groups[groupIndex].members.contains(where: { $0.id.uuidString == memberID }),
              let memberUUID = UUID(uuidString: memberID) else {
            return .result(dialog: IntentDialog(LocalizedStringResource("widgets.groups.send_failed")))
        }
        if snapshot.groups[groupIndex].sentNudgeMemberIDs.contains(memberUUID) {
            return .result(dialog: IntentDialog(LocalizedStringResource("widgets.groups.sent")))
        }

        let request = Self.makeRequest(session: session, groupID: groupID, memberID: memberID, habitID: habitID)
        let delivered: Bool
        let unauthorized: Bool
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            unauthorized = statusCode == 401
            struct NudgeResponse: Decodable { let delivered: Bool? }
            let decoded = try? JSONDecoder().decode(NudgeResponse.self, from: data)
            delivered = statusCode == 200 && decoded?.delivered == true
        } catch {
            delivered = false
            unauthorized = false
        }

        if unauthorized {
            snapshot.sessionExpired = true
            store.writeSnapshot(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
            return .result(dialog: IntentDialog(LocalizedStringResource("widgets.groups.signin")))
        }

        if delivered {
            snapshot.groups[groupIndex].sentNudgeMemberIDs.append(memberUUID)
            snapshot.failedNudgeMemberIDs?.removeAll { $0 == memberUUID }
            store.writeSnapshot(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
            WidgetSupport.postStoreChanged()
            return .result(dialog: IntentDialog(LocalizedStringResource("widgets.groups.sent")))
        }

        snapshot.failedNudgeMemberIDs = (snapshot.failedNudgeMemberIDs ?? []) + [memberUUID]
        store.writeSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: IntentDialog(LocalizedStringResource("widgets.groups.send_failed")))
    }

    private static func makeRequest(session: WidgetSession, groupID: String, memberID: String, habitID: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "\(session.supabaseURL)/functions/v1/send-nudge-push")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(session.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode([
            "group_id": groupID,
            "to_user_id": memberID,
            "habit_id": habitID,
        ])
        return request
    }
}
