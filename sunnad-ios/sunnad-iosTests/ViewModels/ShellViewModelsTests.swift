import Foundation
import Testing
@testable import sunnad_ios

@MainActor
struct ShellViewModelsTests {
    @Test
    func groupsViewModelLoadsPersistedGroupsForSignedInUser() async {
        let habit = UIHabit(customTitle: "Read", iconSystemName: "book.fill", category: .spiritual, completedToday: true, streak: 4)
        let me = GroupMember(
            id: UUID(),
            name: "Ali",
            completedToday: 0,
            totalSharedHabits: 0,
            sharedHabits: []
        )
        let persisted = Group(
            id: UUID(),
            name: "Morning",
            code: "ABC123",
            members: [me],
            sharedHabitIDs: [habit.id],
            ownerMemberID: me.id
        )

        let repository = FakeGroupsRepository(groups: [persisted])
        let vm = GroupsViewModel(groupsRepository: repository, logger: TestLogger())

        await vm.load(user: UIUserState(isGuest: false, name: "Ali", email: "a@b.com"), habits: [habit])

        #expect(vm.groups.count == 1)
        #expect(vm.groups[0].members.first?.completedToday == 1)
        #expect(vm.groups[0].members.first?.sharedHabits.count == 1)
    }

    @Test
    func groupsViewModelCountsOnlyHabitsDueTodayForMemberProgress() async throws {
        let calendar = Calendar.current
        let nonDueWeekday = ((calendar.component(.weekday, from: Date()) + 5) % 7 + 1) % 7

        let dueHabit = UIHabit(
            customTitle: "Due today",
            iconSystemName: "book.fill",
            category: .spiritual,
            completedToday: true,
            schedule: .daily
        )
        let nonDueHabit = UIHabit(
            customTitle: "Not due",
            iconSystemName: "moon.fill",
            category: .spiritual,
            completedToday: true,
            schedule: .weekly,
            weekdays: [nonDueWeekday]
        )
        let me = GroupMember(
            id: UUID(),
            name: "Ali",
            completedToday: 0,
            totalSharedHabits: 0,
            sharedHabits: []
        )
        let persisted = Group(
            id: UUID(),
            name: "Today filter",
            code: "DUE123",
            members: [me],
            sharedHabitIDs: [dueHabit.id, nonDueHabit.id],
            ownerMemberID: me.id
        )

        let repository = FakeGroupsRepository(groups: [persisted])
        let vm = GroupsViewModel(groupsRepository: repository, logger: TestLogger())

        await vm.load(
            user: UIUserState(isGuest: false, name: "Ali", email: "ali@sunnad.app"),
            habits: [dueHabit, nonDueHabit]
        )

        let firstMember = try #require(vm.groups.first?.members.first)
        #expect(firstMember.totalSharedHabits == 1)
        #expect(firstMember.completedToday == 1)
        #expect(firstMember.sharedHabits.count == 1)
        #expect(firstMember.sharedHabits.first?.habitTitle == "Due today")
    }

    @Test
    func groupsViewModelPersistsCreateGroup() async {
        let habit = UIHabit(customTitle: "Read", iconSystemName: "book.fill", category: .spiritual)
        let repository = FakeGroupsRepository(groups: [])
        let vm = GroupsViewModel(groupsRepository: repository, logger: TestLogger())

        await vm.load(user: UIUserState(isGuest: false, name: "Ali", email: "a@b.com"), habits: [habit])
        await vm.createGroup(name: "Circle")

        #expect(vm.groups.count == 1)
        #expect(repository.groups.count == 1)
        #expect(repository.groups[0].name == "Circle")
    }

    @Test
    func groupsViewModelJoinGroupMarksCurrentUserAsNonOwner() async throws {
        let habit = UIHabit(customTitle: "Read", iconSystemName: "book.fill", category: .spiritual)
        let repository = FakeGroupsRepository(groups: [])
        let vm = GroupsViewModel(groupsRepository: repository, logger: TestLogger())

        await vm.load(user: UIUserState(isGuest: false, name: "Ali", email: "a@b.com"), habits: [habit])
        await vm.joinGroup(code: "ABC123")

        #expect(vm.groups.count == 1)
        let group = try #require(vm.groups.first)
        #expect(group.currentUserMemberID != nil)
        #expect(group.currentUserMemberID != group.ownerMemberID)
    }

    @Test
    func groupsViewModelKickMemberRejectedWhenCurrentUserNotOwner() async throws {
        let habit = UIHabit(customTitle: "Read", iconSystemName: "book.fill", category: .spiritual)
        let repository = FakeGroupsRepository(groups: [])
        let vm = GroupsViewModel(groupsRepository: repository, logger: TestLogger())

        await vm.load(user: UIUserState(isGuest: false, name: "Ali", email: "a@b.com"), habits: [habit])
        await vm.joinGroup(code: "ABC123")
        let group = try #require(vm.groups.first)
        let memberCountBefore = group.members.count
        let friendMemberID = try #require(group.members.first(where: { $0.id != group.currentUserMemberID })?.id)

        await vm.kickMember(groupID: group.id, memberID: friendMemberID)

        let updatedGroup = try #require(vm.groups.first)
        #expect(updatedGroup.members.count == memberCountBefore)
    }

    @Test
    func profileViewModelLoadsLocalHabitsAndSavedQuotes() async {
        let habit = Habit(
            id: UUID(),
            name: "Read Quran",
            icon: "book.fill",
            category: .spiritual,
            type: .binary,
            schedule: .daily
        )
        let quote = Quote(id: UUID(), locale: "en", text: "Quote", source: "Source", sortOrder: 0, active: true)

        let habitsRepo = FakeHabitsRepository(habits: [habit])
        let completionsRepo = FakeCompletionsRepository(completionsByHabit: [habit.id: []])
        let quotesRepo = FakeQuotesRepository(quoteOfDay: quote)
        try? await quotesRepo.saveQuote(quote, savedAt: Date())

        let vm = ProfileViewModel(
            habitsRepository: habitsRepo,
            completionsRepository: completionsRepo,
            quotesRepository: quotesRepo,
            logger: TestLogger()
        )

        vm.updateUser(UIUserState(isGuest: false, name: "Ali", email: "a@b.com"))
        await vm.load()

        #expect(vm.habits.count == 1)
        #expect(vm.savedQuotes.count == 1)
        #expect(vm.user.isGuest == false)
    }
}

final class FakeGroupsRepository: GroupsRepository, @unchecked Sendable {
    var groups: [Group]

    init(groups: [Group]) {
        self.groups = groups
    }

    func fetchGroups() async throws -> [Group] {
        groups
    }

    func createGroup(name: String) async throws -> Group {
        let me = GroupMember(name: "Ali", completedToday: 0, totalSharedHabits: 0, sharedHabits: [])
        let group = Group(
            name: name,
            code: "ABC123",
            joinLocked: false,
            members: [me],
            sharedHabitIDs: [],
            ownerMemberID: me.id,
            currentUserMemberID: me.id
        )
        groups.append(group)
        return group
    }

    func joinGroup(code: String) async throws -> Group {
        let owner = GroupMember(name: "Sara", completedToday: 0, totalSharedHabits: 0, sharedHabits: [])
        let me = GroupMember(name: "Ali", completedToday: 0, totalSharedHabits: 0, sharedHabits: [])
        let group = Group(
            name: "Group \(code)",
            code: code,
            joinLocked: false,
            members: [owner, me],
            sharedHabitIDs: [],
            ownerMemberID: owner.id,
            currentUserMemberID: me.id
        )
        groups.append(group)
        return group
    }

    func renameGroup(groupID: UUID, name: String) async throws {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else { return }
        groups[index].name = name
    }

    func setJoinLock(groupID: UUID, locked: Bool) async throws {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else { return }
        groups[index].joinLocked = locked
    }

    func rotateInviteCode(groupID: UUID) async throws -> String {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else { return "NEWCODE" }
        let code = "NEWCODE"
        groups[index].code = code
        return code
    }

    func updateSharing(groupID: UUID, habitIDs: Set<UUID>) async throws {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else { return }
        groups[index].sharedHabitIDs = habitIDs
    }

    func leaveGroup(groupID: UUID) async throws {
        groups.removeAll(where: { $0.id == groupID })
    }

    func deleteGroup(groupID: UUID) async throws {
        groups.removeAll(where: { $0.id == groupID })
    }

    func kickMember(groupID: UUID, memberUserID: UUID) async throws {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else { return }
        groups[index].members.removeAll(where: { $0.id == memberUserID })
    }

    func refreshGroup(groupID: UUID) async throws -> Group? {
        groups.first(where: { $0.id == groupID })
    }

    func sendNudge(groupID: UUID, toUserID: UUID, habitID: UUID) async throws -> GroupNudgeStatus {
        _ = (groupID, toUserID, habitID)
        return .sent
    }

    func replaceGroups(_ groups: [Group]) async throws {
        self.groups = groups
    }
}
