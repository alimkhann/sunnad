import Testing
@testable import sunnad_ios

@MainActor
struct ShellViewModelsTests {
    @Test
    func groupsViewModelPassesThroughData() {
        let vm = GroupsViewModel(groups: [], user: .guest, habits: [])

        let habit = UIHabit(customTitle: "Read", iconSystemName: "book.fill", category: .spiritual)
        let group = UIGroup(name: "Morning", code: "ABC123", members: [], sharedHabitIDs: [habit.id])

        vm.update(groups: [group], user: UIUserState(isGuest: false, name: "Ali", email: "a@b.com"), habits: [habit])

        #expect(vm.groups.count == 1)
        #expect(vm.user.isGuest == false)
        #expect(vm.habits.count == 1)
    }

    @Test
    func profileViewModelPassesThroughData() {
        let vm = ProfileViewModel(user: .guest, habits: [], savedQuotes: [])
        let quote = UISavedQuote(text: "Q", author: "A")

        vm.update(user: UIUserState(isGuest: false, name: "Ali", email: "a@b.com"), habits: [], savedQuotes: [quote])

        #expect(vm.user.isGuest == false)
        #expect(vm.savedQuotes.count == 1)
    }
}
