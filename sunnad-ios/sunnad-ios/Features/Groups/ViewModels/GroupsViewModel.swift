import Combine
import Foundation

@MainActor
final class GroupsViewModel: ObservableObject {
    @Published private(set) var groups: [UIGroup] = []
    @Published private(set) var user: UIUserState = .guest
    @Published private(set) var habits: [UIHabit] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let groupsRepository: GroupsRepository
    private let logger: AnalyticsLogging

    init(
        groupsRepository: GroupsRepository,
        logger: AnalyticsLogging
    ) {
        self.groupsRepository = groupsRepository
        self.logger = logger
    }

    func load(user: UIUserState, habits: [UIHabit]) async {
        self.user = user
        self.habits = habits
        errorMessage = nil

        guard !user.isGuest else {
            groups = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let storedGroups = try await groupsRepository.fetchGroups().map { $0.asUIGroup() }
            groups = refreshGroupProgress(for: storedGroups)
            try await persistCurrentGroups()
        } catch {
            errorMessage = error.localizedDescription
            logger.log(.storageFailure, metadata: ["scope": "groups_load", "error": error.localizedDescription])
        }
    }

    func syncHabits(_ habits: [UIHabit]) async {
        self.habits = habits
        guard !user.isGuest else {
            return
        }

        groups = refreshGroupProgress(for: groups)

        do {
            try await persistCurrentGroups()
        } catch {
            logger.log(.storageFailure, metadata: ["scope": "groups_sync_habits", "error": error.localizedDescription])
        }
    }

    func createGroup(name: String) async {
        guard !user.isGuest else {
            return
        }

        let code = String(UUID().uuidString.prefix(6)).uppercased()
        let me = currentUserMember(sharedHabitIDs: Set(habits.map(\.id)))
        let friend = sampleFriendMember()
        let group = UIGroup(
            name: name,
            code: code,
            members: [me, friend],
            sharedHabitIDs: Set(habits.map(\.id)),
            ownerMemberID: me.id,
            currentUserMemberID: me.id
        )

        groups.append(group)
        groups = refreshGroupProgress(for: groups)

        do {
            try await persistCurrentGroups()
        } catch {
            logger.log(.storageFailure, metadata: ["scope": "groups_create", "error": error.localizedDescription])
        }
    }

    func joinGroup(code: String) async {
        guard !user.isGuest else {
            return
        }

        let me = currentUserMember(sharedHabitIDs: Set(habits.map(\.id)))
        let friend = sampleFriendMember()
        let group = UIGroup(
            name: "\(L10n.t("groups.group")) \(code.uppercased())",
            code: code.uppercased(),
            members: [friend, me],
            sharedHabitIDs: Set(habits.map(\.id)),
            ownerMemberID: friend.id,
            currentUserMemberID: me.id
        )

        groups.append(group)
        groups = refreshGroupProgress(for: groups)

        do {
            try await persistCurrentGroups()
        } catch {
            logger.log(.storageFailure, metadata: ["scope": "groups_join", "error": error.localizedDescription])
        }
    }

    func updateGroupSharing(groupID: UUID, habitIDs: Set<UUID>) async {
        guard let groupIndex = groups.firstIndex(where: { $0.id == groupID }) else {
            return
        }

        groups[groupIndex].sharedHabitIDs = habitIDs
        groups = refreshGroupProgress(for: groups)

        do {
            try await persistCurrentGroups()
        } catch {
            logger.log(.storageFailure, metadata: ["scope": "groups_update_sharing", "error": error.localizedDescription])
        }
    }

    func updateHabitSharing(habitID: UUID, sharedGroupIDs: Set<UUID>) async {
        guard !groups.isEmpty else {
            return
        }

        for index in groups.indices {
            if sharedGroupIDs.contains(groups[index].id) {
                groups[index].sharedHabitIDs.insert(habitID)
            } else {
                groups[index].sharedHabitIDs.remove(habitID)
            }
        }

        groups = refreshGroupProgress(for: groups)

        do {
            try await persistCurrentGroups()
        } catch {
            logger.log(.storageFailure, metadata: ["scope": "groups_update_habit_sharing", "error": error.localizedDescription])
        }
    }

    func leaveGroup(_ groupID: UUID) async {
        groups.removeAll(where: { $0.id == groupID })

        do {
            try await persistCurrentGroups()
        } catch {
            logger.log(.storageFailure, metadata: ["scope": "groups_leave", "error": error.localizedDescription])
        }
    }

    func deleteGroup(_ groupID: UUID) async {
        groups.removeAll(where: { $0.id == groupID })

        do {
            try await persistCurrentGroups()
        } catch {
            logger.log(.storageFailure, metadata: ["scope": "groups_delete", "error": error.localizedDescription])
        }
    }

    func kickMember(groupID: UUID, memberID: UUID) async {
        guard let groupIndex = groups.firstIndex(where: { $0.id == groupID }) else {
            return
        }

        guard groups[groupIndex].ownerMemberID == groups[groupIndex].currentUserMemberID else {
            return
        }

        groups[groupIndex].members.removeAll { $0.id == memberID }

        do {
            try await persistCurrentGroups()
        } catch {
            logger.log(.storageFailure, metadata: ["scope": "groups_kick_member", "error": error.localizedDescription])
        }
    }

    func currentGroupSharedHabitIDs(for groupID: UUID) -> Set<UUID>? {
        groups.first(where: { $0.id == groupID })?.sharedHabitIDs
    }

    private func refreshGroupProgress(for groups: [UIGroup]) -> [UIGroup] {
        groups.map { group in
            var mutable = group
            let myMemberID = mutable.currentUserMemberID ?? mutable.ownerMemberID

            let myHabits = habits.filter { mutable.sharedHabitIDs.contains($0.id) }
            let mySharedHabits = myHabits.map {
                UISharedHabit(
                    habitID: $0.id,
                    habitTitle: $0.displayTitle,
                    habitIconSystemName: $0.iconSystemName,
                    completedToday: $0.completedToday,
                    streak: $0.streak
                )
            }

            let updatedMe = UIGroupMember(
                id: myMemberID,
                name: user.name ?? L10n.t("groups.you"),
                completedToday: myHabits.filter(\.completedToday).count,
                totalSharedHabits: myHabits.count,
                sharedHabits: mySharedHabits
            )

            if let index = mutable.members.firstIndex(where: { $0.id == myMemberID }) {
                mutable.members[index] = updatedMe
            } else {
                mutable.members.insert(updatedMe, at: 0)
            }

            if mutable.currentUserMemberID == nil {
                mutable.currentUserMemberID = updatedMe.id
            }

            return mutable
        }
    }

    private func currentUserMember(sharedHabitIDs: Set<UUID>) -> UIGroupMember {
        let myHabits = habits.filter { sharedHabitIDs.contains($0.id) }
        let mySharedHabits = myHabits.map {
            UISharedHabit(
                habitID: $0.id,
                habitTitle: $0.displayTitle,
                habitIconSystemName: $0.iconSystemName,
                completedToday: $0.completedToday,
                streak: $0.streak
            )
        }

        return UIGroupMember(
            name: user.name ?? L10n.t("groups.you"),
            completedToday: myHabits.filter(\.completedToday).count,
            totalSharedHabits: myHabits.count,
            sharedHabits: mySharedHabits
        )
    }

    private func sampleFriendMember() -> UIGroupMember {
        UIGroupMember(
            name: "Sara",
            completedToday: 2,
            totalSharedHabits: 4,
            sharedHabits: [
                UISharedHabit(
                    habitID: UUID(),
                    habitTitle: L10n.t("habit.read_quran"),
                    habitIconSystemName: "book.fill",
                    completedToday: true,
                    streak: 9
                ),
                UISharedHabit(
                    habitID: UUID(),
                    habitTitle: L10n.t("habit.exercise"),
                    habitIconSystemName: "figure.run",
                    completedToday: false,
                    streak: 2
                )
            ]
        )
    }

    private func persistCurrentGroups() async throws {
        let domainGroups = groups.map { $0.asDomainGroup() }
        try await groupsRepository.replaceGroups(domainGroups)
    }
}
