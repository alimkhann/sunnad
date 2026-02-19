import Combine
import Foundation
import SwiftUI
import UIKit

@MainActor
final class AppRouteState: ObservableObject {
    private enum LocalStateKeys {
        static let onboardingCompleted = "sunnad.onboarding.completed"
    }

    @Published var language: AppLanguage = .en {
        didSet {
            L10n.setLanguage(code: language.localeIdentifier)
            todayViewModel.updateLocale(language.localeIdentifier)
            Task { await loadTodayData() }
        }
    }
    @Published var appearance: AppAppearance = .system
    @Published var notificationPreferences = UINotificationPreferences() {
        didSet {
            dependencies.syncHabitReminders(enabled: notificationPreferences.habitReminders)
        }
    }
    @Published var showsOnboarding = true
    @Published var onboardingStep: OnboardingStep = .welcome

    @Published var activeTab: AppTab = .today
    @Published var rootSheet: RootSheetRoute?
    @Published var fullScreen: FullScreenRoute?

    @Published var user: UIUserState = .guest {
        didSet {
            groupsViewModel.user = user
            profileViewModel.user = user
        }
    }
    @Published var habits: [UIHabit] = [] {
        didSet {
            groupsViewModel.habits = habits
            profileViewModel.habits = habits
        }
    }
    @Published var groups: [UIGroup] = [] {
        didSet {
            groupsViewModel.groups = groups
        }
    }
    @Published var savedQuotes: [UISavedQuote] = [] {
        didSet {
            profileViewModel.savedQuotes = savedQuotes
        }
    }

    @Published var selectedTemplateIDs: Set<String> = []
    @Published var pendingSignUpEmail = ""
    @Published var pendingSignUpUsername = ""
    @Published var todayQuote: UIQuote = UIFixtures.dailyQuote
    @Published private(set) var todayHabitsData: [UIHabit] = []
    @Published private(set) var completionMarksByHabit: [UUID: [Bool]] = [:]

    let todayViewModel: TodayViewModel
    let groupsViewModel: GroupsViewModel
    let profileViewModel: ProfileViewModel

    private let dependencies: DependencyContainer
    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    private var persistTasks: [UUID: Task<Void, Never>] = [:]

    init(dependencies: DependencyContainer) {
        self.dependencies = dependencies
        self.userDefaults = .standard

        let initialHabits = UIFixtures.initialHabits
        let initialSavedQuotes = UIFixtures.initialSavedQuotes

        self.habits = initialHabits
        self.savedQuotes = initialSavedQuotes

        self.todayViewModel = TodayViewModel(
            habitsRepository: dependencies.habitsRepository,
            completionsRepository: dependencies.completionsRepository,
            quotesRepository: dependencies.quotesRepository,
            logger: dependencies.analyticsLogger,
            localeCode: AppLanguage.en.localeIdentifier
        )

        self.groupsViewModel = GroupsViewModel(groups: [], user: .guest, habits: initialHabits)
        self.profileViewModel = ProfileViewModel(user: .guest, habits: initialHabits, savedQuotes: initialSavedQuotes)

        self.showsOnboarding = !userDefaults.bool(forKey: LocalStateKeys.onboardingCompleted)
        L10n.setLanguage(code: language.localeIdentifier)

        bindTodayViewModel()
        bindTimeChangeNotifications()

        #if DEBUG
        applyDebugLaunchOverrides()
        #endif

        Task {
            await loadTodayData()
        }
    }

    var todayHabits: [UIHabit] {
        if !todayHabitsData.isEmpty {
            return todayHabitsData
        }
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
            set: {
                self.habits[index] = $0
                self.updateHabit($0)
            }
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

        replaceLocalHabits(with: habits)
        onboardingStep = .notifications
    }

    func enableOnboardingNotifications() {
        dependencies.requestLocalNotificationPermission()
        onboardingStep = .joinGroups
    }

    func skipOnboardingNotifications() {
        onboardingStep = .joinGroups
    }

    func completeAsGuest() {
        user = .guest
        groups = []
        markOnboardingCompleted()
        activeTab = .today
        Task { await loadTodayData() }
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
        markOnboardingCompleted()
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
        markOnboardingCompleted()
        activeTab = .today
    }

    func verifyOTP() {
        user = UIUserState(isGuest: false, name: pendingSignUpUsername, email: pendingSignUpEmail)
        groups = UIFixtures.groups(user: user, habits: habits)
        markOnboardingCompleted()
        activeTab = .today
    }

    func toggleTodayHabit(_ habitID: UUID) {
        Task {
            await todayViewModel.toggleHabit(habitID)
            await reloadAllHabitsFromStorage()
            refreshGroupProgress()
        }
    }

    func toggleHabit(_ habitID: UUID) {
        toggleTodayHabit(habitID)
    }

    func addTemplateHabits(_ templates: [HabitTemplate]) {
        let existingTemplateKeys = Set(habits.compactMap(\.templateTitleKey))

        for template in templates where !existingTemplateKeys.contains(template.titleKey) {
            let habit = UIHabit(
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
            habits.append(habit)
            persistHabit(habit)
        }
    }

    func addCustomHabit(
        name: String,
        iconSystemName: String,
        category: HabitCategory,
        schedule: UIHabitSchedule,
        weekdays: Set<Int>,
        reminderTime: Date?,
        hasDhikrCounter: Bool
    ) {
        let habit = UIHabit(
            customTitle: name,
            iconSystemName: iconSystemName,
            category: category,
            completedToday: false,
            streak: 0,
            schedule: schedule,
            weekdays: weekdays,
            reminderTime: reminderTime,
            isDhikr: hasDhikrCounter,
            dhikrCount: 0,
            dhikrTarget: hasDhikrCounter ? 33 : 0
        )

        habits.append(habit)
        persistHabit(habit)
    }

    func updateHabit(_ habit: UIHabit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else {
            return
        }

        habits[index] = habit
        persistHabit(habit)
        refreshGroupProgress()
    }

    func deleteHabit(_ habitID: UUID) {
        habits.removeAll(where: { $0.id == habitID })
        for index in groups.indices {
            groups[index].sharedHabitIDs.remove(habitID)
        }

        Task {
            do {
                try await dependencies.habitsRepository.deleteHabit(id: habitID)
                await dependencies.reminderScheduler.removeReminder(habitID: habitID)
                await loadTodayData()
            } catch {
                dependencies.analyticsLogger.log(.storageFailure, metadata: ["scope": "delete_habit", "error": error.localizedDescription])
            }
        }

        refreshGroupProgress()
    }

    func saveCurrentQuote() {
        Task {
            await todayViewModel.saveCurrentQuote()
        }
    }

    func saveQuote(_ quote: UIQuote) {
        let item = UISavedQuote(text: quote.text, author: quote.author)
        savedQuotes.insert(item, at: 0)
    }

    func signInFromGroups() {
        openProfileSignIn()
    }

    func openProfileSignIn() {
        fullScreen = .profileSignIn
    }

    func openProfileSignUp() {
        fullScreen = .profileSignUp
    }

    func handleProfileSignIn(username: String, password: String) {
        handleSignIn(username: username, password: password)
        fullScreen = nil
    }

    func handleProfileSignUp(email: String, username: String, password: String, method: String) {
        if method == "email" {
            pendingSignUpEmail = email
            pendingSignUpUsername = username
            fullScreen = .profileOTP
            return
        }

        user = UIUserState(isGuest: false, name: username.isEmpty ? "User" : username, email: email.isEmpty ? "user@example.com" : email)
        groups = UIFixtures.groups(user: user, habits: habits)
        markOnboardingCompleted()
        fullScreen = nil
    }

    func verifyProfileOTP() {
        user = UIUserState(isGuest: false, name: pendingSignUpUsername, email: pendingSignUpEmail)
        groups = UIFixtures.groups(user: user, habits: habits)
        markOnboardingCompleted()
        fullScreen = nil
    }

    func signOut() {
        user = .guest
        groups = []
    }

    func deleteData() {
        habits = []
        savedQuotes = []
        groups = []
        selectedTemplateIDs = []
    }

    func deleteAccount() {
        deleteData()
        pendingSignUpEmail = ""
        pendingSignUpUsername = ""
        user = .guest
        userDefaults.set(false, forKey: LocalStateKeys.onboardingCompleted)
        showsOnboarding = true
        onboardingStep = .welcome
        activeTab = .today
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

    func updateHabitSharing(habitID: UUID, sharedGroupIDs: Set<UUID>) {
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

        refreshGroupProgress()
    }

    func leaveGroup(_ groupID: UUID) {
        groups.removeAll { $0.id == groupID }
    }

    func deleteGroup(_ groupID: UUID) {
        groups.removeAll { $0.id == groupID }
    }

    func kickMember(groupID: UUID, memberID: UUID) {
        guard let groupIndex = groups.firstIndex(where: { $0.id == groupID }) else {
            return
        }

        guard groups[groupIndex].ownerMemberID == groups[groupIndex].members.first?.id else {
            return
        }

        groups[groupIndex].members.removeAll { $0.id == memberID }
    }

    private func bindTodayViewModel() {
        todayViewModel.$habits
            .receive(on: DispatchQueue.main)
            .sink { [weak self] habits in
                self?.todayHabitsData = habits
            }
            .store(in: &cancellables)

        todayViewModel.$quote
            .receive(on: DispatchQueue.main)
            .sink { [weak self] quote in
                self?.todayQuote = quote
            }
            .store(in: &cancellables)

        todayViewModel.$savedQuotes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] savedQuotes in
                self?.savedQuotes = savedQuotes
            }
            .store(in: &cancellables)
    }

    func lastSevenCompletionMarks(for habitID: UUID) -> [Bool]? {
        completionMarksByHabit[habitID]
    }

    private func bindTimeChangeNotifications() {
        let dayChanged = NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
        let significantTimeChanged = NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
        let timeZoneChanged = NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)
        let willEnterForeground = NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)

        Publishers.MergeMany(dayChanged, significantTimeChanged, timeZoneChanged, willEnterForeground)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.loadTodayData() }
            }
            .store(in: &cancellables)
    }

    private func loadTodayData() async {
        await reloadAllHabitsFromStorage()
        await todayViewModel.loadToday()
        dependencies.syncHabitReminders(enabled: notificationPreferences.habitReminders)
        refreshGroupProgress()
    }

    private func reloadAllHabitsFromStorage() async {
        do {
            let today = Date()
            let domainHabits = try await dependencies.habitsRepository.fetchHabits(includeArchived: false)
            var mapped: [UIHabit] = []
            var marksByHabit: [UUID: [Bool]] = [:]
            mapped.reserveCapacity(domainHabits.count)

            for habit in domainHabits {
                let completion = try await dependencies.completionsRepository.fetchCompletion(
                    habitID: habit.id,
                    on: today,
                    calendar: .current,
                    timeZone: .current
                ) ?? HabitCompletion(habitID: habit.id, dayDate: today, value: 0)

                let history = try await dependencies.completionsRepository.fetchCompletions(for: habit.id)
                let streak = StreakCalculator.streak(for: habit, completions: history, asOf: today)
                marksByHabit[habit.id] = Self.lastSevenMarks(
                    for: habit,
                    completions: history,
                    asOf: today,
                    calendar: .current,
                    timeZone: .current
                )

                mapped.append(
                    habit.asUIHabit(
                        completedToday: completion.isCompleted(for: habit),
                        streak: streak,
                        completionValue: completion.value
                    )
                )
            }

            habits = mapped
            completionMarksByHabit = marksByHabit
        } catch {
            dependencies.analyticsLogger.log(.storageFailure, metadata: ["scope": "reload_habits", "error": error.localizedDescription])
        }
    }

    private func persistHabit(_ habit: UIHabit) {
        persistTasks[habit.id]?.cancel()
        persistTasks[habit.id] = Task { @MainActor [weak self] in
            guard let self else { return }
            var domain = habit.asDomainHabit()

            if let index = self.habits.firstIndex(where: { $0.id == habit.id }) {
                domain.sortOrder = index
            }

            do {
                try await self.dependencies.habitsRepository.saveHabit(domain)

                if habit.isDhikr {
                    let now = Date()
                    let value = min(max(habit.dhikrCount, 0), domain.normalizedTargetCount)
                    let completion = HabitCompletion(
                        habitID: habit.id,
                        dayDate: now,
                        value: value,
                        completedAt: value > 0 ? now : nil,
                        updatedAt: now
                    )
                    try await self.dependencies.completionsRepository.upsertCompletion(
                        completion,
                        calendar: .current,
                        timeZone: .current
                    )
                }

                if Task.isCancelled {
                    return
                }

                await self.loadTodayData()
            } catch is CancellationError {
                return
            } catch {
                self.dependencies.analyticsLogger.log(.storageFailure, metadata: ["scope": "save_habit", "error": error.localizedDescription])
            }

            self.persistTasks[habit.id] = nil
        }
    }

    private func markOnboardingCompleted() {
        userDefaults.set(true, forKey: LocalStateKeys.onboardingCompleted)
        showsOnboarding = false
    }

    private static func lastSevenMarks(
        for habit: Habit,
        completions: [HabitCompletion],
        asOf date: Date,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> [Bool] {
        var calendar = calendar
        calendar.timeZone = timeZone

        let startOfToday = calendar.startOfDay(for: date)
        let completionByDay = Dictionary(
            uniqueKeysWithValues: completions.map { (calendar.startOfDay(for: $0.dayDate), $0) }
        )

        return (-6...0).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else {
                return nil
            }

            guard habit.isDue(on: day, calendar: calendar, timeZone: timeZone) else {
                return false
            }

            guard let completion = completionByDay[day] else {
                return false
            }

            return completion.isCompleted(for: habit)
        }
    }

    private func replaceLocalHabits(with habits: [UIHabit]) {
        Task {
            do {
                let existing = try await dependencies.habitsRepository.fetchHabits(includeArchived: true)
                for habit in existing {
                    try await dependencies.habitsRepository.deleteHabit(id: habit.id)
                }

                for (index, habit) in habits.enumerated() {
                    var domain = habit.asDomainHabit()
                    domain.sortOrder = index
                    try await dependencies.habitsRepository.saveHabit(domain)
                }

                await loadTodayData()
            } catch {
                dependencies.analyticsLogger.log(.storageFailure, metadata: ["scope": "replace_habits", "error": error.localizedDescription])
            }
        }
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

        if let rawLanguage = environment["SUNNAD_DEBUG_LANGUAGE"]?.lowercased(),
           let debugLanguage = AppLanguage(rawValue: rawLanguage) {
            language = debugLanguage
        }

        if let step = environment["SUNNAD_DEBUG_ONBOARDING_STEP"]?.lowercased() {
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

        if isTruthy(environment["SUNNAD_DEBUG_SKIP_ONBOARDING"]) {
            showsOnboarding = false
            onboardingStep = .welcome
        }

        if let rawUser = environment["SUNNAD_DEBUG_USER"]?.lowercased() {
            switch rawUser {
            case "signed_in", "signedin", "member":
                user = UIUserState(isGuest: false, name: "User", email: "user@example.com")
                groups = UIFixtures.groups(user: user, habits: habits)
            case "guest":
                user = .guest
                groups = []
            default:
                break
            }
        }

        if let rawTab = environment["SUNNAD_DEBUG_TAB"]?.lowercased() {
            switch rawTab {
            case "today":
                activeTab = .today
            case "groups":
                activeTab = .groups
            case "profile":
                activeTab = .profile
            default:
                break
            }
        }

        if let rawSheet = environment["SUNNAD_DEBUG_ROOT_SHEET"]?.lowercased() {
            switch rawSheet {
            case "add_habit", "addhabit":
                rootSheet = .addHabit
            case "habit_detail", "habitdetail":
                if environment["SUNNAD_DEBUG_HABIT_DETAIL_TYPE"]?.lowercased() == "dhikr",
                   let dhikrHabit = habits.first(where: \.isDhikr) {
                    rootSheet = .habitDetail(dhikrHabit.id)
                } else if let first = habits.first {
                    rootSheet = .habitDetail(first.id)
                }
            case "quote", "quote_of_day":
                rootSheet = .quoteOfDay
            case "create_group":
                rootSheet = .createGroup
            case "join_group":
                rootSheet = .joinGroup
            case "saved_quotes":
                rootSheet = .savedQuotes
            case "language_picker":
                rootSheet = .languagePicker
            case "reminder_placeholder":
                rootSheet = .reminderPlaceholder
            default:
                break
            }
        }

        if let rawFull = environment["SUNNAD_DEBUG_FULL_SCREEN"]?.lowercased() {
            switch rawFull {
            case "schedule":
                fullScreen = .schedule
            case "insights":
                fullScreen = .insightsPlaceholder
            case "week":
                fullScreen = .weekPlaceholder
            case "month":
                fullScreen = .monthPlaceholder
            default:
                break
            }
        }
    }

    private func isTruthy(_ value: String?) -> Bool {
        guard let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }

        return normalized == "1" || normalized == "true" || normalized == "yes"
    }
    #endif
}
