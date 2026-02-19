import Combine
import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var user: UIUserState
    @Published var habits: [UIHabit]
    @Published var savedQuotes: [UISavedQuote]

    init(user: UIUserState, habits: [UIHabit], savedQuotes: [UISavedQuote]) {
        self.user = user
        self.habits = habits
        self.savedQuotes = savedQuotes
    }

    func update(user: UIUserState, habits: [UIHabit], savedQuotes: [UISavedQuote]) {
        self.user = user
        self.habits = habits
        self.savedQuotes = savedQuotes
    }
}
