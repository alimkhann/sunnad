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

    func replaceGroups(_ groups: [Group]) async throws {
        self.groups = groups
    }
}
