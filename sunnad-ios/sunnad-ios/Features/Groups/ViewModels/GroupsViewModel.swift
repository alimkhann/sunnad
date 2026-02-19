import Combine
import Foundation

@MainActor
final class GroupsViewModel: ObservableObject {
    @Published var groups: [UIGroup]
    @Published var user: UIUserState
    @Published var habits: [UIHabit]

    init(groups: [UIGroup], user: UIUserState, habits: [UIHabit]) {
        self.groups = groups
        self.user = user
        self.habits = habits
    }

    func update(groups: [UIGroup], user: UIUserState, habits: [UIHabit]) {
        self.groups = groups
        self.user = user
        self.habits = habits
    }
}
