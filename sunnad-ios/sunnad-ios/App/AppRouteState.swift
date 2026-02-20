import Combine
import Foundation
import SwiftUI
import UIKit

@MainActor
final class AppRouteState: ObservableObject {
    private enum LocalStateKeys {
        static let onboardingCompleted = "sunnad.onboarding.completed"
        static let pendingPasswordRecovery = "sunnad.auth.pending-password-recovery"
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
            Task { await refreshDebugReminderCountIfNeeded() }
        }
    }
    @Published var showsOnboarding = true
    @Published var onboardingStep: OnboardingStep = .welcome

    @Published var activeTab: AppTab = .today
    @Published var rootSheet: RootSheetRoute?
    @Published var fullScreen: FullScreenRoute?

    @Published var user: UIUserState = .guest {
        didSet {
            profileViewModel.updateUser(user)
            Task {
                await groupsViewModel.load(user: user, habits: habits)
            }
        }
    }
    @Published var habits: [UIHabit] = [] {
        didSet {
            Task {
                await groupsViewModel.syncHabits(habits)
            }
        }
    }

    @Published var selectedTemplateIDs: Set<String> = []
    @Published var pendingSignUpEmail = ""
    @Published var pendingSignUpUsername = ""
    @Published var pendingPasswordResetEmail = ""
    @Published var todayQuote: UIQuote = UIFixtures.dailyQuote
    @Published private(set) var authErrorMessage: String?
    @Published private(set) var authSuccessMessage: String?
    @Published private(set) var todayHabitsData: [UIHabit] = []
    @Published private(set) var completionMarksByHabit: [UUID: [Bool]] = [:]
    @Published private(set) var debugPendingReminderCount = 0

    var publicAppLink: URL {
        dependencies.environment.publicAppLink
    }

    var privacyURL: URL {
        dependencies.environment.privacyURL
    }

    var helpURL: URL {
        dependencies.environment.helpURL
    }

    var isUITestMode: Bool {
        #if DEBUG
        return isTruthy(ProcessInfo.processInfo.environment["SUNNAD_UI_TEST_MODE"])
        #else
        return false
        #endif
    }

    let todayViewModel: TodayViewModel
    let groupsViewModel: GroupsViewModel
    let profileViewModel: ProfileViewModel
    let insightsViewModel: InsightsViewModel

    private let dependencies: DependencyContainer
    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    private var persistTasks: [UUID: Task<Void, Never>] = [:]

    init(dependencies: DependencyContainer, userDefaults: UserDefaults = .standard) {
        self.dependencies = dependencies
        self.userDefaults = userDefaults

        let initialHabits = UIFixtures.initialHabits

        self.habits = initialHabits

        self.todayViewModel = TodayViewModel(
            habitsRepository: dependencies.habitsRepository,
            completionsRepository: dependencies.completionsRepository,
            quotesRepository: dependencies.quotesRepository,
            logger: dependencies.analyticsLogger,
            localeCode: AppLanguage.en.localeIdentifier
        )

        self.groupsViewModel = GroupsViewModel(
            groupsRepository: dependencies.groupsRepository,
            logger: dependencies.analyticsLogger
        )
        self.profileViewModel = ProfileViewModel(
            habitsRepository: dependencies.habitsRepository,
            completionsRepository: dependencies.completionsRepository,
            quotesRepository: dependencies.quotesRepository,
            logger: dependencies.analyticsLogger
        )
        self.insightsViewModel = InsightsViewModel(
            habitsRepository: dependencies.habitsRepository,
            completionsRepository: dependencies.completionsRepository,
            logger: dependencies.analyticsLogger
        )

        self.showsOnboarding = !userDefaults.bool(forKey: LocalStateKeys.onboardingCompleted)
        L10n.setLanguage(code: language.localeIdentifier)

        bindTodayViewModel()
        bindChildViewModels()
        bindTimeChangeNotifications()

        #if DEBUG
        applyDebugLaunchOverrides()
        #endif

        Task {
            await restoreAuthSessionIfNeeded()
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
        clearAuthError()
        onboardingStep = .signIn
    }

    func openSignUp() {
        clearAuthError()
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
        markOnboardingCompleted()
        activeTab = .today
        Task { await loadTodayData() }
    }

    func handleSignIn(identifier: String, password: String) {
        Task {
            do {
                let sessionUser = try await dependencies.authService.signIn(
                    identifier: identifier.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
                authErrorMessage = nil
                authSuccessMessage = nil
                user = sessionUser.asUIUserState
                await dependencies.deviceTokenSyncService.syncCurrentDeviceToken(for: sessionUser.id)
                markOnboardingCompleted()
                activeTab = .today
            } catch {
                authSuccessMessage = nil
                authErrorMessage = error.localizedDescription
                dependencies.analyticsLogger.log(
                    .storageFailure,
                    metadata: ["scope": "auth_sign_in", "error": error.localizedDescription]
                )
            }
        }
    }

    func handleSignUp(email: String, username: String, password: String, method: String) {
        guard method == "email" else {
            authErrorMessage = AuthServiceError.unavailable.localizedDescription
            dependencies.analyticsLogger.log(.storageFailure, metadata: ["scope": "auth_sign_up_provider", "provider": method])
            return
        }

        Task {
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            do {
                let sessionUser = try await dependencies.authService.signUp(
                    email: normalizedEmail,
                    password: password,
                    username: normalizedUsername
                )
                authErrorMessage = nil
                authSuccessMessage = nil
                user = sessionUser.asUIUserState
                await dependencies.deviceTokenSyncService.syncCurrentDeviceToken(for: sessionUser.id)
                markOnboardingCompleted()
                activeTab = .today
                onboardingStep = .joinGroups
            } catch {
                if case AuthServiceError.emailNotConfirmed = error {
                    pendingSignUpEmail = normalizedEmail
                    pendingSignUpUsername = normalizedUsername
                    authErrorMessage = nil
                    authSuccessMessage = L10n.t("auth.otp.sent")
                    onboardingStep = .otp
                    return
                }
                authSuccessMessage = nil
                authErrorMessage = error.localizedDescription
                dependencies.analyticsLogger.log(
                    .storageFailure,
                    metadata: ["scope": "auth_sign_up", "error": error.localizedDescription]
                )
            }
        }
    }

    func verifyOTP(code: String) {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = pendingSignUpEmail
        guard !email.isEmpty else {
            authErrorMessage = AuthServiceError.invalidCredentials.localizedDescription
            return
        }

        Task {
            do {
                let sessionUser = try await dependencies.authService.verifyEmailOTP(
                    email: email,
                    code: normalizedCode
                )
                authErrorMessage = nil
                authSuccessMessage = nil
                user = sessionUser.asUIUserState
                await dependencies.deviceTokenSyncService.syncCurrentDeviceToken(for: sessionUser.id)
                markOnboardingCompleted()
                activeTab = .today
                onboardingStep = .joinGroups
            } catch {
                authSuccessMessage = nil
                authErrorMessage = error.localizedDescription
                dependencies.analyticsLogger.log(
                    .storageFailure,
                    metadata: ["scope": "auth_verify_otp", "error": error.localizedDescription]
                )
            }
        }
    }

    func resendOTP() {
        let email = pendingSignUpEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else {
            authErrorMessage = AuthServiceError.invalidCredentials.localizedDescription
            return
        }

        Task {
            do {
                try await dependencies.authService.resendSignUpOTP(
                    email: email,
                    redirectTo: dependencies.environment.authRedirectURL
                )
                authErrorMessage = nil
                authSuccessMessage = L10n.t("auth.otp.resent")
            } catch {
                authSuccessMessage = nil
                authErrorMessage = error.localizedDescription
                dependencies.analyticsLogger.log(
                    .storageFailure,
                    metadata: ["scope": "auth_resend_otp", "error": error.localizedDescription]
                )
            }
        }
    }

    func toggleTodayHabit(_ habitID: UUID) {
        Task {
            await todayViewModel.toggleHabit(habitID)
            await loadTodayData()
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
    }

    func reorderHabits(_ reordered: [UIHabit]) {
        habits = reordered

        Task {
            do {
                for (index, habit) in reordered.enumerated() {
                    var domain = habit.asDomainHabit()
                    domain.sortOrder = index
                    try await dependencies.habitsRepository.saveHabit(domain)
                }
                await loadTodayData()
            } catch {
                dependencies.analyticsLogger.log(.storageFailure, metadata: ["scope": "reorder_habits", "error": error.localizedDescription])
            }
        }
    }

    func deleteHabit(_ habitID: UUID) {
        habits.removeAll(where: { $0.id == habitID })

        Task {
            do {
                try await dependencies.habitsRepository.deleteHabit(id: habitID)
                await groupsViewModel.updateHabitSharing(habitID: habitID, sharedGroupIDs: [])
                await dependencies.reminderScheduler.removeReminder(habitID: habitID)
                await loadTodayData()
            } catch {
                dependencies.analyticsLogger.log(.storageFailure, metadata: ["scope": "delete_habit", "error": error.localizedDescription])
            }
        }
    }

    func saveCurrentQuote() {
        Task {
            await todayViewModel.saveCurrentQuote()
            await profileViewModel.load()
        }
    }

    func signInFromGroups() {
        openProfileSignIn()
    }

    func openProfileSignIn() {
        clearAuthError()
        fullScreen = .profileSignIn
    }

    func openProfileSignUp() {
        clearAuthError()
        fullScreen = .profileSignUp
    }

    func clearAuthError() {
        authErrorMessage = nil
        authSuccessMessage = nil
    }

    func openOnboardingForgotPassword(prefill identifier: String) {
        pendingPasswordResetEmail = resolveEmailFromIdentifier(identifier)
        clearAuthError()
        fullScreen = .forgotPasswordOnboarding
    }

    func openProfileForgotPassword(prefill identifier: String) {
        pendingPasswordResetEmail = resolveEmailFromIdentifier(identifier)
        clearAuthError()
        fullScreen = .forgotPasswordProfile
    }

    func closeOnboardingForgotPassword() {
        clearAuthError()
        fullScreen = nil
    }

    func closeProfileForgotPassword() {
        clearAuthError()
        fullScreen = .profileSignIn
    }

    func submitPasswordResetRequest(email: String) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingPasswordResetEmail = normalizedEmail

        Task {
            do {
                try await dependencies.authService.requestPasswordReset(
                    email: normalizedEmail,
                    redirectTo: dependencies.environment.authRedirectURL
                )
                userDefaults.set(true, forKey: LocalStateKeys.pendingPasswordRecovery)
                authErrorMessage = nil
                authSuccessMessage = L10n.t("auth.forgot_password.sent")
                dependencies.analyticsLogger.log(
                    .syncFinished,
                    metadata: ["scope": "auth_password_reset", "status": "email_sent"]
                )
            } catch {
                authSuccessMessage = nil
                authErrorMessage = error.localizedDescription
                dependencies.analyticsLogger.log(
                    .storageFailure,
                    metadata: ["scope": "auth_password_reset", "error": error.localizedDescription]
                )
            }
        }
    }

    func openChangePassword() {
        clearAuthError()
        fullScreen = .changePassword
    }

    func submitChangePassword(newPassword: String) {
        Task {
            do {
                let sessionUser = try await dependencies.authService.updatePassword(newPassword: newPassword)
                authErrorMessage = nil
                authSuccessMessage = L10n.t("auth.change_password.updated")
                user = sessionUser.asUIUserState
                fullScreen = nil
                userDefaults.set(false, forKey: LocalStateKeys.pendingPasswordRecovery)
                await dependencies.deviceTokenSyncService.syncCurrentDeviceToken(for: sessionUser.id)
                await profileViewModel.load()
            } catch {
                authSuccessMessage = nil
                authErrorMessage = error.localizedDescription
                dependencies.analyticsLogger.log(
                    .storageFailure,
                    metadata: ["scope": "auth_change_password", "error": error.localizedDescription]
                )
            }
        }
    }

    func handleIncomingURL(_ url: URL) {
        guard isPotentialAuthCallbackURL(url) else {
            return
        }

        let recoveryPending = userDefaults.bool(forKey: LocalStateKeys.pendingPasswordRecovery)
        let shouldOpenRecoveryPassword = Self.isRecoveryCallbackURL(url) || recoveryPending
        if shouldOpenRecoveryPassword {
            fullScreen = .changePassword
        }

        Task {
            do {
                guard let sessionUser = try await dependencies.authService.handleAuthCallback(url: url) else {
                    return
                }

                authErrorMessage = nil
                authSuccessMessage = nil
                user = sessionUser.asUIUserState
                await dependencies.deviceTokenSyncService.syncCurrentDeviceToken(for: sessionUser.id)
                markOnboardingCompleted()
                activeTab = .profile

                if shouldOpenRecoveryPassword {
                    userDefaults.set(false, forKey: LocalStateKeys.pendingPasswordRecovery)
                }
            } catch {
                authSuccessMessage = nil
                authErrorMessage = error.localizedDescription
                dependencies.analyticsLogger.log(
                    .storageFailure,
                    metadata: ["scope": "auth_callback", "error": error.localizedDescription]
                )
            }
        }
    }

    func handleProfileSignIn(identifier: String, password: String) {
        Task {
            do {
                let sessionUser = try await dependencies.authService.signIn(
                    identifier: identifier.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
                authErrorMessage = nil
                authSuccessMessage = nil
                user = sessionUser.asUIUserState
                await dependencies.deviceTokenSyncService.syncCurrentDeviceToken(for: sessionUser.id)
                markOnboardingCompleted()
                fullScreen = nil
            } catch {
                authSuccessMessage = nil
                authErrorMessage = error.localizedDescription
                dependencies.analyticsLogger.log(
                    .storageFailure,
                    metadata: ["scope": "auth_profile_sign_in", "error": error.localizedDescription]
                )
            }
        }
    }

    func handleProfileSignUp(email: String, username: String, password: String, method: String) {
        guard method == "email" else {
            authErrorMessage = AuthServiceError.unavailable.localizedDescription
            dependencies.analyticsLogger.log(.storageFailure, metadata: ["scope": "auth_profile_sign_up_provider", "provider": method])
            return
        }

        Task {
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            do {
                let sessionUser = try await dependencies.authService.signUp(
                    email: normalizedEmail,
                    password: password,
                    username: normalizedUsername
                )
                authErrorMessage = nil
                authSuccessMessage = nil
                user = sessionUser.asUIUserState
                await dependencies.deviceTokenSyncService.syncCurrentDeviceToken(for: sessionUser.id)
                markOnboardingCompleted()
                fullScreen = nil
            } catch {
                if case AuthServiceError.emailNotConfirmed = error {
                    pendingSignUpEmail = normalizedEmail
                    pendingSignUpUsername = normalizedUsername
                    authErrorMessage = nil
                    authSuccessMessage = L10n.t("auth.otp.sent")
                    fullScreen = .profileOTP
                    return
                }
                authSuccessMessage = nil
                authErrorMessage = error.localizedDescription
                dependencies.analyticsLogger.log(
                    .storageFailure,
                    metadata: ["scope": "auth_profile_sign_up", "error": error.localizedDescription]
                )
            }
        }
    }

    func verifyProfileOTP(code: String) {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = pendingSignUpEmail
        guard !email.isEmpty else {
            authErrorMessage = AuthServiceError.invalidCredentials.localizedDescription
            return
        }

        Task {
            do {
                let sessionUser = try await dependencies.authService.verifyEmailOTP(
                    email: email,
                    code: normalizedCode
                )
                authErrorMessage = nil
                authSuccessMessage = nil
                user = sessionUser.asUIUserState
                await dependencies.deviceTokenSyncService.syncCurrentDeviceToken(for: sessionUser.id)
                markOnboardingCompleted()
                fullScreen = nil
            } catch {
                authSuccessMessage = nil
                authErrorMessage = error.localizedDescription
                dependencies.analyticsLogger.log(
                    .storageFailure,
                    metadata: ["scope": "auth_profile_verify_otp", "error": error.localizedDescription]
                )
            }
        }
    }

    func resendProfileOTP() {
        resendOTP()
    }

    func signOut() {
        Task {
            do {
                try await dependencies.authService.signOut()
            } catch {
                dependencies.analyticsLogger.log(
                    .storageFailure,
                    metadata: ["scope": "auth_sign_out", "error": error.localizedDescription]
                )
            }

            authErrorMessage = nil
            authSuccessMessage = nil
            user = .guest
        }
    }

    func deleteData() {
        Task {
            await clearLocalData()
            selectedTemplateIDs = []
            pendingSignUpEmail = ""
            pendingSignUpUsername = ""
            await loadTodayData()
        }
    }

    func deleteAccount() {
        Task {
            do {
                try await dependencies.authService.deleteAccount()
            } catch {
                authErrorMessage = error.localizedDescription
                dependencies.analyticsLogger.log(
                    .storageFailure,
                    metadata: ["scope": "auth_delete_account", "error": error.localizedDescription]
                )
                return
            }

            await clearLocalData()
            selectedTemplateIDs = []
            pendingSignUpEmail = ""
            pendingSignUpUsername = ""
            user = .guest
            authErrorMessage = nil
            authSuccessMessage = nil
            markOnboardingCompleted()
            rootSheet = nil
            fullScreen = nil
            activeTab = .profile
            await profileViewModel.load()
        }
    }

    func createGroup(name: String) {
        Task {
            await groupsViewModel.createGroup(name: name)
        }
    }

    func joinGroup(code: String) {
        Task {
            await groupsViewModel.joinGroup(code: code)
        }
    }

    func updateGroupSharing(groupID: UUID, habitIDs: Set<UUID>) {
        Task {
            await groupsViewModel.updateGroupSharing(groupID: groupID, habitIDs: habitIDs)
        }
    }

    func updateHabitSharing(habitID: UUID, sharedGroupIDs: Set<UUID>) {
        Task {
            await groupsViewModel.updateHabitSharing(habitID: habitID, sharedGroupIDs: sharedGroupIDs)
        }
    }

    func leaveGroup(_ groupID: UUID) {
        Task {
            await groupsViewModel.leaveGroup(groupID)
        }
    }

    func deleteGroup(_ groupID: UUID) {
        Task {
            await groupsViewModel.deleteGroup(groupID)
        }
    }

    func kickMember(groupID: UUID, memberID: UUID) {
        Task {
            await groupsViewModel.kickMember(groupID: groupID, memberID: memberID)
        }
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

    }

    private func bindChildViewModels() {
        groupsViewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        profileViewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        insightsViewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
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
        await profileViewModel.load()
        dependencies.syncHabitReminders(enabled: notificationPreferences.habitReminders)
        await refreshDebugReminderCountIfNeeded()
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

    private func clearLocalData() async {
        do {
            let allHabits = try await dependencies.habitsRepository.fetchHabits(includeArchived: true)

            for habit in allHabits {
                let completions = try await dependencies.completionsRepository.fetchCompletions(for: habit.id)
                for completion in completions {
                    try await dependencies.completionsRepository.deleteCompletion(
                        habitID: habit.id,
                        on: completion.dayDate,
                        calendar: .current,
                        timeZone: .current
                    )
                }

                await dependencies.reminderScheduler.removeReminder(habitID: habit.id)
                try await dependencies.habitsRepository.deleteHabit(id: habit.id)
            }

            try await dependencies.quotesRepository.deleteAllSavedQuotes()
            try await dependencies.groupsRepository.replaceGroups([])

            habits = []
            todayHabitsData = []
            completionMarksByHabit = [:]
            await groupsViewModel.load(user: user, habits: [])
            await profileViewModel.load()
            await refreshDebugReminderCountIfNeeded()
        } catch {
            dependencies.analyticsLogger.log(.storageFailure, metadata: ["scope": "clear_local_data", "error": error.localizedDescription])
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
                    let maxTrackedCount = ([habit.dhikrCount] + Array(habit.dhikrCountsByKey.values)).max() ?? 0
                    let value = min(max(maxTrackedCount, 0), domain.normalizedTargetCount)
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

    private func restoreAuthSessionIfNeeded() async {
        if let sessionUser = await dependencies.authService.currentUser() {
            authErrorMessage = nil
            authSuccessMessage = nil
            user = sessionUser.asUIUserState
            await dependencies.deviceTokenSyncService.syncCurrentDeviceToken(for: sessionUser.id)
            markOnboardingCompleted()
        }
    }

    private func resolveEmailFromIdentifier(_ identifier: String) -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") ? trimmed : ""
    }

    private func isPotentialAuthCallbackURL(_ url: URL) -> Bool {
        if Self.hasCallbackAuthPayload(url) {
            return true
        }

        let normalizedPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedHost = (url.host ?? "").lowercased()
        let expected = dependencies.environment.authRedirectURL
        let expectedPath = expected.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let expectedHost = (expected.host ?? "").lowercased()

        return (url.scheme ?? "").lowercased() == (expected.scheme ?? "").lowercased()
            && normalizedHost == expectedHost
            && normalizedPath == expectedPath
    }

    private static func hasCallbackAuthPayload(_ url: URL) -> Bool {
        let raw = url.absoluteString.lowercased()
        return raw.contains("access_token=")
            || raw.contains("refresh_token=")
            || raw.contains("code=")
            || raw.contains("token=")
            || raw.contains("token_hash=")
            || raw.contains("type=recovery")
            || raw.contains("type=signup")
    }

    private static func isRecoveryCallbackURL(_ url: URL) -> Bool {
        let raw = url.absoluteString.lowercased()
        return raw.contains("type=recovery")
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

    private func refreshDebugReminderCountIfNeeded() async {
        #if DEBUG
        guard isUITestMode else {
            return
        }

        do {
            try await Task.sleep(nanoseconds: 120_000_000)
        } catch {
            return
        }

        guard let debugScheduler = dependencies.reminderScheduler as? ReminderSchedulingDebugInspectable else {
            return
        }

        let identifiers = await debugScheduler.debugPendingReminderRequestIdentifiers()
        debugPendingReminderCount = identifiers.count
        #endif
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
            case "guest":
                user = .guest
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

private extension SessionUser {
    var asUIUserState: UIUserState {
        UIUserState(isGuest: false, name: displayName, email: email)
    }
}
