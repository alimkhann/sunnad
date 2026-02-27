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
    private var sharingUpdateRevisions: [UUID: Int] = [:]

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

        await refresh()
    }

    func refresh() async {
        guard !user.isGuest else {
            groups = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedGroups = try await groupsRepository.fetchGroups().map { $0.asUIGroup() }
            groups = refreshGroupProgress(for: fetchedGroups)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            logger.log(.storageFailure, metadata: ["scope": "groups_refresh", "error": error.localizedDescription])
        }
    }

    func refreshGroup(groupID: UUID) async {
        guard !user.isGuest else { return }
        do {
            if let group = try await groupsRepository.refreshGroup(groupID: groupID)?.asUIGroup() {
                mergeOrAppend(group)
                groups = refreshGroupProgress(for: groups)
            } else {
                groups.removeAll(where: { $0.id == groupID })
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            logger.log(.storageFailure, metadata: ["scope": "groups_refresh_group", "error": error.localizedDescription])
        }
    }

    func syncHabits(_ habits: [UIHabit]) async {
        self.habits = habits
        guard !user.isGuest else { return }
        groups = refreshGroupProgress(for: groups)
    }

    func createGroup(name: String) async {
        guard !user.isGuest else { return }
        do {
            let group = try await groupsRepository
                .createGroup(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
                .asUIGroup()
            mergeOrAppend(group)
            groups = refreshGroupProgress(for: groups)
            await refresh()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            logger.log(.storageFailure, metadata: ["scope": "groups_create", "error": error.localizedDescription])
        }
    }

    func joinGroup(code: String) async {
        guard !user.isGuest else { return }
        do {
            let group = try await groupsRepository.joinGroup(code: code).asUIGroup()
            mergeOrAppend(group)
            groups = refreshGroupProgress(for: groups)
            await refresh()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            logger.log(.storageFailure, metadata: ["scope": "groups_join", "error": error.localizedDescription])
        }
    }

    func renameGroup(groupID: UUID, name: String) async {
        do {
            try await groupsRepository.renameGroup(groupID: groupID, name: name.trimmingCharacters(in: .whitespacesAndNewlines))
            await refreshGroup(groupID: groupID)
        } catch {
            errorMessage = error.localizedDescription
            logger.log(.storageFailure, metadata: ["scope": "groups_rename", "error": error.localizedDescription])
        }
    }

    func setGroupJoinLock(groupID: UUID, locked: Bool) async {
        do {
            try await groupsRepository.setJoinLock(groupID: groupID, locked: locked)
            await refreshGroup(groupID: groupID)
        } catch {
            errorMessage = error.localizedDescription
            logger.log(.storageFailure, metadata: ["scope": "groups_set_lock", "error": error.localizedDescription])
        }
    }

    func rotateInviteCode(groupID: UUID) async {
        do {
            _ = try await groupsRepository.rotateInviteCode(groupID: groupID)
            await refreshGroup(groupID: groupID)
        } catch {
            errorMessage = error.localizedDescription
            logger.log(.storageFailure, metadata: ["scope": "groups_rotate_code", "error": error.localizedDescription])
        }
    }

    func updateGroupSharing(groupID: UUID, habitIDs: Set<UUID>) async {
        let revision = (sharingUpdateRevisions[groupID] ?? 0) + 1
        sharingUpdateRevisions[groupID] = revision

        applyOptimisticSharing(groupID: groupID, habitIDs: habitIDs)

        do {
            try await groupsRepository.updateSharing(groupID: groupID, habitIDs: habitIDs)
            guard sharingUpdateRevisions[groupID] == revision else {
                return
            }
            await refreshGroup(groupID: groupID)
        } catch {
            guard sharingUpdateRevisions[groupID] == revision else {
                return
            }
            errorMessage = error.localizedDescription
            await refreshGroup(groupID: groupID)
            logger.log(.storageFailure, metadata: ["scope": "groups_update_sharing", "error": error.localizedDescription])
        }
    }

    func updateHabitSharing(habitID: UUID, sharedGroupIDs: Set<UUID>) async {
        guard !groups.isEmpty else { return }
        do {
            for group in groups {
                var habitIDs = group.sharedHabitIDs
                if sharedGroupIDs.contains(group.id) {
                    habitIDs.insert(habitID)
                } else {
                    habitIDs.remove(habitID)
                }
                try await groupsRepository.updateSharing(groupID: group.id, habitIDs: habitIDs)
            }
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
            logger.log(.storageFailure, metadata: ["scope": "groups_update_habit_sharing", "error": error.localizedDescription])
        }
    }

    func leaveGroup(_ groupID: UUID) async {
        do {
            try await groupsRepository.leaveGroup(groupID: groupID)
            groups.removeAll(where: { $0.id == groupID })
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            logger.log(.storageFailure, metadata: ["scope": "groups_leave", "error": error.localizedDescription])
        }
    }

    func deleteGroup(_ groupID: UUID) async {
        do {
            try await groupsRepository.deleteGroup(groupID: groupID)
            groups.removeAll(where: { $0.id == groupID })
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            logger.log(.storageFailure, metadata: ["scope": "groups_delete", "error": error.localizedDescription])
        }
    }

    func kickMember(groupID: UUID, memberID: UUID) async {
        guard let group = groups.first(where: { $0.id == groupID }) else {
            return
        }
        guard group.ownerMemberID == group.currentUserMemberID else {
            return
        }

        do {
            try await groupsRepository.kickMember(groupID: groupID, memberUserID: memberID)
            await refreshGroup(groupID: groupID)
        } catch {
            errorMessage = error.localizedDescription
            logger.log(.storageFailure, metadata: ["scope": "groups_kick_member", "error": error.localizedDescription])
        }
    }

    func sendNudge(groupID: UUID, memberID: UUID, habitID: UUID) async -> GroupNudgeStatus {
        do {
            return try await groupsRepository.sendNudge(groupID: groupID, toUserID: memberID, habitID: habitID)
        } catch {
            logger.log(.storageFailure, metadata: ["scope": "groups_send_nudge", "error": error.localizedDescription])
            return .error
        }
    }

    func currentGroupSharedHabitIDs(for groupID: UUID) -> Set<UUID>? {
        groups.first(where: { $0.id == groupID })?.sharedHabitIDs
    }

    private func mergeOrAppend(_ group: UIGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
        } else {
            groups.append(group)
        }
    }

    private func refreshGroupProgress(for groups: [UIGroup]) -> [UIGroup] {
        let today = Date()
        return groups.map { group in
            var mutable = group
            let myMemberID = mutable.currentUserMemberID ?? mutable.ownerMemberID

            let myHabits = habits.filter {
                mutable.sharedHabitIDs.contains($0.id) && $0.isScheduled(on: today)
            }
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
                avatarURL: user.avatarURL,
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

    private func applyOptimisticSharing(groupID: UUID, habitIDs: Set<UUID>) {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else {
            return
        }
        groups[index].sharedHabitIDs = habitIDs
        groups = refreshGroupProgress(for: groups)
    }
}
