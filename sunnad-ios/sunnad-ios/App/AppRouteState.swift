import Combine
import Foundation
import SwiftUI

@MainActor
final class AppRouteState: ObservableObject {
    @Published var language: AppLanguage = .en
    @Published var showsOnboarding = true
    @Published var onboardingStep: OnboardingStep = .welcome

    @Published var activeTab: AppTab = .today
    @Published var rootSheet: RootSheetRoute?
    @Published var fullScreen: FullScreenRoute?

    @Published var user: UIUserState = .guest
    @Published var habits: [UIHabit] = []
    @Published var groups: [UIGroup] = []
    @Published var savedQuotes: [UISavedQuote] = []

    @Published var selectedTemplateIDs: Set<String> = []
    @Published var pendingSignUpEmail = ""
    @Published var pendingSignUpUsername = ""

    init() {
        habits = UIFixtures.initialHabits
        savedQuotes = UIFixtures.initialSavedQuotes
        #if DEBUG
        applyDebugLaunchOverrides()
        #endif
    }

    var todayHabits: [UIHabit] {
        let today = Date()
        return habits.filter { $0.isScheduled(on: today) }
    }

    var selectedHabit: UIHabit? {
        guard case .habitDetail(let habitID) = rootSheet else {
            return nil
        }

        return habits.first(where: { $0.id == habitID })
    }

    func bindingForHabit(habitID: UUID) -> Binding<UIHabit>? {
        guard let index = habits.firstIndex(where: { $0.id == habitID }) else {
            return nil
        }

        return Binding(
            get: { self.habits[index] },
            set: { self.habits[index] = $0 }
        )
    }

    func moveOnboardingForward() {
        switch onboardingStep {
        case .welcome:
            onboardingStep = .templates
        case .templates:
            onboardingStep = .notifications
        case .notifications:
            onboardingStep = .joinGroups
        case .joinGroups:
            completeAsGuest()
        case .signIn, .signUp, .otp:
            break
        }
    }

    func openSignIn() {
        onboardingStep = .signIn
    }

    func openSignUp() {
        onboardingStep = .signUp
    }

    func completeTemplateSelection() {
        let selected = UIFixtures.templates.filter { selectedTemplateIDs.contains($0.id) }

        if selected.isEmpty {
            habits = UIFixtures.initialHabits
        } else {
            habits = selected.map {
                UIHabit(
                    templateTitleKey: $0.titleKey,
                    iconSystemName: $0.iconSystemName,
                    category: $0.category,
                    completedToday: false,
                    streak: 0,
                    schedule: .daily,
                    isDhikr: $0.isDhikr,
                    dhikrCount: 0,
                    dhikrTarget: $0.isDhikr ? 33 : 0
                )
            }
        }

        onboardingStep = .notifications
    }

    func completeAsGuest() {
        user = .guest
        groups = []
        showsOnboarding = false
        activeTab = .today
    }

    func handleSignIn(username: String, password: String) {
        let email: String
        if password == "apple" || password == "google" {
            email = "\(username.lowercased())@example.com"
        } else {
            email = "user@example.com"
        }

        user = UIUserState(isGuest: false, name: username, email: email)
        groups = UIFixtures.groups(user: user, habits: habits)
        showsOnboarding = false
        activeTab = .today
    }

    func handleSignUp(email: String, username: String, password: String, method: String) {
        if method == "email" {
            pendingSignUpEmail = email
            pendingSignUpUsername = username
            onboardingStep = .otp
            return
        }

        user = UIUserState(isGuest: false, name: username.isEmpty ? "User" : username, email: email.isEmpty ? "user@example.com" : email)
        groups = UIFixtures.groups(user: user, habits: habits)
        showsOnboarding = false
        activeTab = .today
    }

    func verifyOTP() {
        user = UIUserState(isGuest: false, name: pendingSignUpUsername, email: pendingSignUpEmail)
        groups = UIFixtures.groups(user: user, habits: habits)
        showsOnboarding = false
        activeTab = .today
    }

    func toggleHabit(_ habitID: UUID) {
        guard let index = habits.firstIndex(where: { $0.id == habitID }) else {
            return
        }

        habits[index].completedToday.toggle()
        refreshGroupProgress()
    }

    func addTemplateHabits(_ templates: [HabitTemplate]) {
        let existingTemplateKeys = Set(habits.compactMap(\.templateTitleKey))

        for template in templates where !existingTemplateKeys.contains(template.titleKey) {
            habits.append(
                UIHabit(
                    templateTitleKey: template.titleKey,
                    iconSystemName: template.iconSystemName,
                    category: template.category,
                    completedToday: false,
                    streak: 0,
                    schedule: .daily,
                    isDhikr: template.isDhikr,
                    dhikrCount: 0,
                    dhikrTarget: template.isDhikr ? 33 : 0
                )
            )
        }
    }

    func addCustomHabit(
        name: String,
        iconSystemName: String,
        category: HabitCategory,
        schedule: HabitSchedule,
        weekdays: Set<Int>,
        reminderTime: Date?
    ) {
        habits.append(
            UIHabit(
                customTitle: name,
                iconSystemName: iconSystemName,
                category: category,
                completedToday: false,
                streak: 0,
                schedule: schedule,
                weekdays: weekdays,
                reminderTime: reminderTime,
                isDhikr: false,
                dhikrCount: 0,
                dhikrTarget: 0
            )
        )
    }

    func updateHabit(_ habit: UIHabit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else {
            return
        }

        habits[index] = habit
        refreshGroupProgress()
    }

    func deleteHabit(_ habitID: UUID) {
        habits.removeAll(where: { $0.id == habitID })
        for index in groups.indices {
            groups[index].sharedHabitIDs.remove(habitID)
        }
        refreshGroupProgress()
    }

    func saveQuote(_ quote: UIQuote) {
        let item = UISavedQuote(text: quote.text, author: quote.author)
        savedQuotes.insert(item, at: 0)
    }

    func signInFromGroups() {
        user = UIUserState(isGuest: false, name: "John Doe", email: "john@example.com")
        groups = UIFixtures.groups(user: user, habits: habits)
    }

    func signOut() {
        user = .guest
        groups = []
    }

    func createGroup(name: String) {
        let code = String(UUID().uuidString.prefix(6)).uppercased()
        let newGroup = UIGroup(
            name: name,
            code: code,
            members: defaultMembers(),
            sharedHabitIDs: Set(habits.map(\.id))
        )
        groups.append(newGroup)
    }

    func joinGroup(code: String) {
        let group = UIGroup(
            name: "\(L10n.t("groups.group")) \(code.uppercased())",
            code: code.uppercased(),
            members: defaultMembers(),
            sharedHabitIDs: Set(habits.map(\.id))
        )
        groups.append(group)
    }

    func updateGroupSharing(groupID: UUID, habitIDs: Set<UUID>) {
        guard let groupIndex = groups.firstIndex(where: { $0.id == groupID }) else {
            return
        }

        groups[groupIndex].sharedHabitIDs = habitIDs
        refreshGroupProgress(for: groupID)
    }

    private func defaultMembers() -> [UIGroupMember] {
        let me = UIGroupMember(
            name: user.name ?? L10n.t("groups.you"),
            completedToday: habits.filter(\.completedToday).count,
            totalSharedHabits: habits.count,
            sharedHabits: habits.map {
                UISharedHabit(
                    habitID: $0.id,
                    habitTitle: $0.displayTitle,
                    habitIconSystemName: $0.iconSystemName,
                    completedToday: $0.completedToday,
                    streak: $0.streak
                )
            }
        )

        let friend = UIGroupMember(
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

        return [me, friend]
    }

    private func refreshGroupProgress(for groupID: UUID? = nil) {
        for index in groups.indices {
            if let groupID, groups[index].id != groupID {
                continue
            }

            let selectedHabitIDs = groups[index].sharedHabitIDs
            let myHabits = habits.filter { selectedHabitIDs.contains($0.id) }
            let mySharedHabits = myHabits.map {
                UISharedHabit(
                    habitID: $0.id,
                    habitTitle: $0.displayTitle,
                    habitIconSystemName: $0.iconSystemName,
                    completedToday: $0.completedToday,
                    streak: $0.streak
                )
            }

            guard !groups[index].members.isEmpty else {
                continue
            }

            groups[index].members[0] = UIGroupMember(
                id: groups[index].members[0].id,
                name: groups[index].members[0].name,
                completedToday: myHabits.filter(\.completedToday).count,
                totalSharedHabits: myHabits.count,
                sharedHabits: mySharedHabits
            )
        }
    }

    #if DEBUG
    private func applyDebugLaunchOverrides() {
        let environment = ProcessInfo.processInfo.environment
        guard let step = environment["SUNNAD_DEBUG_ONBOARDING_STEP"]?.lowercased() else {
            return
        }

        showsOnboarding = true

        switch step {
        case "welcome":
            onboardingStep = .welcome
        case "templates":
            onboardingStep = .templates
        case "notifications":
            onboardingStep = .notifications
        case "join_groups", "joingroups":
            onboardingStep = .joinGroups
        case "signin", "sign_in":
            onboardingStep = .signIn
        case "signup", "sign_up":
            onboardingStep = .signUp
        case "otp":
            onboardingStep = .otp
            pendingSignUpEmail = environment["SUNNAD_DEBUG_EMAIL"] ?? "alimkhan.ergebayev@gmail.com"
            pendingSignUpUsername = environment["SUNNAD_DEBUG_USERNAME"] ?? "alimkhan"
        default:
            break
        }
    }
    #endif
}
