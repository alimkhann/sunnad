import Combine
import Foundation

@MainActor
final class GroupsViewModel: ObservableObject {
    private struct SharingPipelineState {
        var desiredHabitIDs: Set<UUID>
        var committedHabitIDs: Set<UUID>
        var isInFlight: Bool
    }

    @Published private(set) var groups: [UIGroup] = []
    @Published private(set) var user: UIUserState = .guest
    @Published private(set) var habits: [UIHabit] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let groupsRepository: GroupsRepository
    private let logger: AnalyticsLogging
    private let analytics: AnalyticsClient
    private var sharingPipelines: [UUID: SharingPipelineState] = [:]

    init(
        groupsRepository: GroupsRepository,
        logger: AnalyticsLogging,
        analytics: AnalyticsClient
    ) {
        self.groupsRepository = groupsRepository
        self.logger = logger
        self.analytics = analytics
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
            sharingPipelines = [:]
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedGroups = try await groupsRepository.fetchGroups().map { group in
                var uiGroup = group.asUIGroup()
                uiGroup.sharedHabitIDs = resolvedSharedHabitIDs(
                    for: uiGroup.id,
                    fallback: uiGroup.sharedHabitIDs
                )
                return uiGroup
            }
            groups = refreshGroupProgress(for: fetchedGroups)
            syncSharingPipelines(with: groups)
            errorMessage = nil
        } catch {
            errorMessage = friendlyGroupError(error, fallback: L10n.t("groups.errors.load"))
            logger.log(.storageFailure, metadata: ["scope": "groups_refresh", "error": error.localizedDescription])
        }
    }

    func refreshGroup(groupID: UUID) async {
        guard !user.isGuest else { return }
        do {
            if var group = try await groupsRepository.refreshGroup(groupID: groupID)?.asUIGroup() {
                group.sharedHabitIDs = resolvedSharedHabitIDs(
                    for: group.id,
                    fallback: group.sharedHabitIDs
                )
                mergeOrAppend(group)
                groups = refreshGroupProgress(for: groups)
                syncSharingPipeline(for: groupID)
            } else {
                groups.removeAll(where: { $0.id == groupID })
                sharingPipelines.removeValue(forKey: groupID)
            }
            errorMessage = nil
        } catch {
            errorMessage = friendlyGroupError(error, fallback: L10n.t("groups.errors.load"))
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
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else { return }

        let pendingGroup = makePendingGroup(name: normalizedName, code: "…")
        groups.append(pendingGroup)
        groups = refreshGroupProgress(for: groups)

        do {
            let group = try await groupsRepository
                .createGroup(name: normalizedName)
                .asUIGroup()
            replacePendingGroup(withID: pendingGroup.id, with: group)
            groups = refreshGroupProgress(for: groups)
            syncSharingPipeline(for: group.id)
            errorMessage = nil
            analytics.trackGroup(.created)
        } catch {
            groups.removeAll(where: { $0.id == pendingGroup.id })
            groups = refreshGroupProgress(for: groups)
            errorMessage = friendlyGroupError(error, fallback: L10n.t("groups.errors.create"))
            logger.log(.storageFailure, metadata: ["scope": "groups_create", "error": error.localizedDescription])
        }
    }

    func joinGroup(code: String) async {
        guard !user.isGuest else { return }
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedCode.isEmpty else { return }

        let pendingGroup = makePendingGroup(
            name: "\(L10n.t("groups.join")) \(normalizedCode)",
            code: normalizedCode
        )
        groups.append(pendingGroup)
        groups = refreshGroupProgress(for: groups)

        do {
            let group = try await groupsRepository.joinGroup(code: normalizedCode).asUIGroup()
            replacePendingGroup(withID: pendingGroup.id, with: group)
            groups = refreshGroupProgress(for: groups)
            syncSharingPipeline(for: group.id)
            errorMessage = nil
            analytics.trackGroup(.joinResult(status: "success", reason: nil))
        } catch {
            groups.removeAll(where: { $0.id == pendingGroup.id })
            groups = refreshGroupProgress(for: groups)
            errorMessage = friendlyGroupError(error, fallback: L10n.t("groups.errors.join"))
            logger.log(.storageFailure, metadata: ["scope": "groups_join", "error": error.localizedDescription])
            analytics.trackGroup(.joinResult(status: "failure", reason: "error"))
        }
    }

    func renameGroup(groupID: UUID, name: String) async {
        do {
            try await groupsRepository.renameGroup(groupID: groupID, name: name.trimmingCharacters(in: .whitespacesAndNewlines))
            await refreshGroup(groupID: groupID)
        } catch {
            errorMessage = friendlyGroupError(error, fallback: L10n.t("groups.errors.rename"))
            logger.log(.storageFailure, metadata: ["scope": "groups_rename", "error": error.localizedDescription])
        }
    }

    func setGroupJoinLock(groupID: UUID, locked: Bool) async {
        do {
            try await groupsRepository.setJoinLock(groupID: groupID, locked: locked)
            await refreshGroup(groupID: groupID)
        } catch {
            errorMessage = friendlyGroupError(error, fallback: L10n.t("groups.errors.permissions"))
            logger.log(.storageFailure, metadata: ["scope": "groups_set_lock", "error": error.localizedDescription])
        }
    }

    func rotateInviteCode(groupID: UUID) async {
        do {
            _ = try await groupsRepository.rotateInviteCode(groupID: groupID)
            await refreshGroup(groupID: groupID)
        } catch {
            errorMessage = friendlyGroupError(error, fallback: L10n.t("groups.errors.permissions"))
            logger.log(.storageFailure, metadata: ["scope": "groups_rotate_code", "error": error.localizedDescription])
        }
    }

    func updateGroupSharing(groupID: UUID, habitIDs: Set<UUID>) async {
        guard !user.isGuest else { return }
        let currentSharedHabitIDs = groups.first(where: { $0.id == groupID })?.sharedHabitIDs ?? []
        applyOptimisticSharing(groupID: groupID, habitIDs: habitIDs)
        var pipeline = sharingPipelines[groupID] ?? SharingPipelineState(
            desiredHabitIDs: habitIDs,
            committedHabitIDs: currentSharedHabitIDs,
            isInFlight: false
        )
        pipeline.desiredHabitIDs = habitIDs
        sharingPipelines[groupID] = pipeline

        await flushSharingPipeline(groupID: groupID)
    }

    func updateHabitSharing(habitID: UUID, sharedGroupIDs: Set<UUID>) async {
        guard !groups.isEmpty else { return }

        // Optimistic: update UI immediately
        var snapshotByGroup: [UUID: Set<UUID>] = [:]
        for group in groups where !group.isPending {
            snapshotByGroup[group.id] = group.sharedHabitIDs
            var habitIDs = group.sharedHabitIDs
            if sharedGroupIDs.contains(group.id) {
                habitIDs.insert(habitID)
            } else {
                habitIDs.remove(habitID)
            }
            applyOptimisticSharing(groupID: group.id, habitIDs: habitIDs)
        }

        // Persist to remote
        do {
            for group in groups where !group.isPending {
                try await groupsRepository.updateSharing(groupID: group.id, habitIDs: group.sharedHabitIDs)
            }
        } catch {
            // Rollback on failure
            for (groupID, original) in snapshotByGroup {
                applyOptimisticSharing(groupID: groupID, habitIDs: original)
            }
            errorMessage = friendlyGroupError(error, fallback: L10n.t("groups.errors.permissions"))
            logger.log(.storageFailure, metadata: ["scope": "groups_update_habit_sharing", "error": error.localizedDescription])
        }
    }

    func leaveGroup(_ groupID: UUID) async {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else {
            return
        }
        let removedGroup = groups.remove(at: index)
        sharingPipelines.removeValue(forKey: groupID)
        groups = refreshGroupProgress(for: groups)

        do {
            try await groupsRepository.leaveGroup(groupID: groupID)
            errorMessage = nil
            analytics.trackGroup(.left)
        } catch {
            groups.insert(removedGroup, at: min(index, groups.count))
            groups = refreshGroupProgress(for: groups)
            syncSharingPipeline(for: groupID)
            errorMessage = friendlyGroupError(error, fallback: L10n.t("groups.errors.permissions"))
            logger.log(.storageFailure, metadata: ["scope": "groups_leave", "error": error.localizedDescription])
        }
    }

    func deleteGroup(_ groupID: UUID) async {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else {
            return
        }
        let removedGroup = groups.remove(at: index)
        sharingPipelines.removeValue(forKey: groupID)
        groups = refreshGroupProgress(for: groups)

        do {
            try await groupsRepository.deleteGroup(groupID: groupID)
            errorMessage = nil
        } catch {
            groups.insert(removedGroup, at: min(index, groups.count))
            groups = refreshGroupProgress(for: groups)
            syncSharingPipeline(for: groupID)
            errorMessage = friendlyGroupError(error, fallback: L10n.t("groups.errors.permissions"))
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
            errorMessage = friendlyGroupError(error, fallback: L10n.t("groups.errors.permissions"))
            logger.log(.storageFailure, metadata: ["scope": "groups_kick_member", "error": error.localizedDescription])
        }
    }

    func setProgressDisplayMode(groupID: UUID, mode: GroupProgressDisplayMode) async {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else { return }
        groups[index].progressDisplayMode = mode
        do {
            try await groupsRepository.setProgressDisplayMode(groupID: groupID, mode: mode)
            await refreshGroup(groupID: groupID)
        } catch {
            errorMessage = friendlyGroupError(error, fallback: L10n.t("groups.errors.permissions"))
            logger.log(.storageFailure, metadata: ["scope": "groups_set_progress_mode", "error": error.localizedDescription])
        }
    }

    func sendNudge(groupID: UUID, memberID: UUID, habitID: UUID) async -> GroupNudgeStatus {
        let habitType = habits.first(where: { $0.id == habitID })?.isDhikr == true ? "dhikr" : "binary"
        do {
            let status = try await groupsRepository.sendNudge(
                groupID: groupID,
                toUserID: memberID,
                habitID: habitID
            )
            let statusValue: String
            switch status {
            case .delivered:
                statusValue = "delivered"
            case .alreadyDelivered:
                statusValue = "already_delivered"
            case .recipientNotRegistered:
                statusValue = "recipient_not_registered"
            case .forbidden:
                statusValue = "forbidden"
            case .error:
                statusValue = "error"
            }
            analytics.trackGroup(.nudgeResult(status: statusValue, habitType: habitType))
            return status
        } catch {
            logger.log(.storageFailure, metadata: ["scope": "groups_send_nudge", "error": error.localizedDescription])
            analytics.trackGroup(.nudgeResult(status: "error", habitType: habitType))
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

    private func replacePendingGroup(withID pendingID: UUID, with group: UIGroup) {
        groups.removeAll(where: { $0.id == pendingID })
        mergeOrAppend(group)
    }

    private func refreshGroupProgress(for groups: [UIGroup]) -> [UIGroup] {
        return groups.map { group in
            var mutable = group
            let myMemberID = mutable.currentUserMemberID ?? mutable.ownerMemberID
            let serverMember = mutable.members.first(where: { $0.id == myMemberID })
            let serverSharedHabitsByID = Dictionary(
                uniqueKeysWithValues: (serverMember?.sharedHabits ?? []).map { ($0.habitID, $0) }
            )
            let today = Date()
            let localSharedHabits = habits.filter { mutable.sharedHabitIDs.contains($0.id) }
            let localDueSharedHabits = localSharedHabits
                .filter { $0.isScheduled(on: today) }
                .sorted { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending }
                .map {
                    UISharedHabit(
                        habitID: $0.id,
                        habitTitle: $0.displayTitle,
                        habitIconSystemName: $0.iconSystemName,
                        completedToday: $0.completedToday,
                        dueToday: true,
                        streak: $0.streak,
                        rollingCompletionPercent: serverSharedHabitsByID[$0.id]?.rollingCompletionPercent
                    )
                }
            let resolvedSharedHabits: [UISharedHabit]
            if !localSharedHabits.isEmpty || mutable.sharedHabitIDs.isEmpty {
                resolvedSharedHabits = localDueSharedHabits
            } else {
                resolvedSharedHabits = serverMember?.sharedHabits.filter(\.dueToday) ?? []
            }
            let updatedMe = UIGroupMember(
                id: myMemberID,
                userID: serverMember?.userID ?? myMemberID,
                name: user.name ?? serverMember?.name ?? L10n.t("groups.you"),
                avatarURL: user.avatarURL ?? serverMember?.avatarURL,
                completedToday: resolvedSharedHabits.count { $0.completedToday },
                totalSharedHabits: resolvedSharedHabits.count,
                sharedHabits: resolvedSharedHabits
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

    private func makePendingGroup(name: String, code: String) -> UIGroup {
        let currentUserMember = UIGroupMember(
            id: UUID(),
            name: user.name ?? L10n.t("groups.you"),
            avatarURL: user.avatarURL,
            completedToday: 0,
            totalSharedHabits: 0,
            sharedHabits: []
        )

        return UIGroup(
            id: UUID(),
            name: name,
            code: code,
            joinLocked: false,
            members: [currentUserMember],
            sharedHabitIDs: [],
            ownerMemberID: currentUserMember.id,
            currentUserMemberID: currentUserMember.id,
            isPending: true
        )
    }

    private func syncSharingPipelines(with groups: [UIGroup]) {
        let knownGroupIDs = Set(groups.map(\.id))
        sharingPipelines = sharingPipelines.filter { knownGroupIDs.contains($0.key) }
        for group in groups {
            if let current = sharingPipelines[group.id],
               current.isInFlight || current.desiredHabitIDs != current.committedHabitIDs {
                continue
            }
            sharingPipelines[group.id] = SharingPipelineState(
                desiredHabitIDs: group.sharedHabitIDs,
                committedHabitIDs: group.sharedHabitIDs,
                isInFlight: false
            )
        }
    }

    private func syncSharingPipeline(for groupID: UUID) {
        guard let group = groups.first(where: { $0.id == groupID }) else {
            sharingPipelines.removeValue(forKey: groupID)
            return
        }
        if let current = sharingPipelines[groupID],
           current.isInFlight || current.desiredHabitIDs != current.committedHabitIDs {
            return
        }
        sharingPipelines[groupID] = SharingPipelineState(
            desiredHabitIDs: group.sharedHabitIDs,
            committedHabitIDs: group.sharedHabitIDs,
            isInFlight: false
        )
    }

    private func resolvedSharedHabitIDs(for groupID: UUID, fallback: Set<UUID>) -> Set<UUID> {
        guard let pipeline = sharingPipelines[groupID] else {
            return fallback
        }
        if pipeline.isInFlight || pipeline.desiredHabitIDs != pipeline.committedHabitIDs {
            return pipeline.desiredHabitIDs
        }
        return fallback
    }

    private func flushSharingPipeline(groupID: UUID) async {
        guard var pipeline = sharingPipelines[groupID] else {
            return
        }
        guard !pipeline.isInFlight else {
            return
        }
        guard pipeline.desiredHabitIDs != pipeline.committedHabitIDs else {
            return
        }

        let targetHabitIDs = pipeline.desiredHabitIDs
        let previousCommitted = pipeline.committedHabitIDs
        pipeline.isInFlight = true
        sharingPipelines[groupID] = pipeline

        do {
            try await groupsRepository.updateSharing(groupID: groupID, habitIDs: targetHabitIDs)
            let refreshedGroup = try await groupsRepository.refreshGroup(groupID: groupID)?.asUIGroup()

            var latest = sharingPipelines[groupID] ?? pipeline
            let committedHabitIDs = refreshedGroup?.sharedHabitIDs ?? targetHabitIDs
            let serverCorrectedSelection =
                committedHabitIDs != targetHabitIDs && latest.desiredHabitIDs == targetHabitIDs

            if serverCorrectedSelection {
                latest = SharingPipelineState(
                    desiredHabitIDs: committedHabitIDs,
                    committedHabitIDs: committedHabitIDs,
                    isInFlight: false
                )
            } else {
                latest.committedHabitIDs = committedHabitIDs
                latest.isInFlight = false
            }
            sharingPipelines[groupID] = latest

            if var refreshedGroup {
                refreshedGroup.sharedHabitIDs = resolvedSharedHabitIDs(
                    for: refreshedGroup.id,
                    fallback: refreshedGroup.sharedHabitIDs
                )
                mergeOrAppend(refreshedGroup)
                groups = refreshGroupProgress(for: groups)
            } else {
                applyOptimisticSharing(groupID: groupID, habitIDs: committedHabitIDs)
            }

            if serverCorrectedSelection {
                applyOptimisticSharing(groupID: groupID, habitIDs: committedHabitIDs)
                errorMessage = L10n.t("groups.errors.unsyncedHabits")
                return
            }

            let delta = committedHabitIDs.count - previousCommitted.count
            if delta != 0 {
                analytics.trackGroup(.sharingUpdated(delta: delta, totalShared: committedHabitIDs.count))
            }

            if latest.desiredHabitIDs != latest.committedHabitIDs {
                await flushSharingPipeline(groupID: groupID)
            }
        } catch {
            var latest = sharingPipelines[groupID] ?? pipeline
            latest.isInFlight = false
            let hasNewerDesiredState = latest.desiredHabitIDs != targetHabitIDs
            sharingPipelines[groupID] = latest

            if hasNewerDesiredState {
                await flushSharingPipeline(groupID: groupID)
                return
            }

            errorMessage = friendlyGroupError(error, fallback: L10n.t("groups.errors.sharing"))
            applyOptimisticSharing(groupID: groupID, habitIDs: latest.committedHabitIDs)
            logger.log(.storageFailure, metadata: ["scope": "groups_update_sharing", "error": error.localizedDescription])
        }
    }

    private func friendlyGroupError(_ error: Error, fallback: String) -> String {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return fallback }
        let lower = message.lowercased()
        if lower.contains("group_shared_habits_habit_id_fkey") {
            return L10n.t("groups.errors.unsyncedHabits")
        }
        if lower.contains("invalid") && lower.contains("code") {
            return L10n.t("groups.errors.invalidCode")
        }
        if lower.contains("locked") || lower.contains("closed") {
            return L10n.t("groups.errors.locked")
        }
        if lower.contains("permission") || lower.contains("forbidden") {
            return L10n.t("groups.errors.permissions")
        }
        return message
    }
}
