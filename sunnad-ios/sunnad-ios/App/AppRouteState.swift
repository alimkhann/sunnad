import Combine
import Foundation
import Network
import SwiftUI
import UIKit
#if canImport(OneSignalFramework)
import OneSignalFramework
#endif

@MainActor
final class AppRouteState: ObservableObject {
    private enum LocalStateKeys {
        static let onboardingCompleted = "sunnad.onboarding.completed"
        static let pendingPasswordRecovery = "sunnad.auth.pending-password-recovery"
        static let pendingOAuthIntent = "sunnad.auth.pending-oauth-intent"
        static let habitRemindersEnabled = "sunnad.notifications.habit.enabled"
        static let quoteRemindersEnabled = "sunnad.notifications.quote.enabled"
        static let groupRemindersEnabled = "sunnad.notifications.group.enabled"
        static let hapticsEnabled = "sunnad.feedback.haptics.enabled"
        static let soundsEnabled = "sunnad.feedback.sounds.enabled"
        static func analyticsFirstSeenDate(distinctID: String) -> String {
            "sunnad.analytics.first_seen.\(distinctID)"
        }
    }

    private enum PasswordRecoverySource {
        case onboarding
        case profile
    }

    private enum OAuthProvider {
        case google
        case apple

        var scope: String {
            switch self {
            case .google:
                return "google"
            case .apple:
                return "apple"
            }
        }
    }

    private enum OAuthIntent: String {
        case signIn = "sign_in"
        case signUp = "sign_up"
    }

    private enum GuestPromotionMode {
        case none
        case signup
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
            persistNotificationPreferences()
            dependencies.syncHabitReminders(enabled: notificationPreferences.habitReminders)
            dependencies.syncQuoteReminders(
                enabled: notificationPreferences.quoteReminder,
                locale: language.localeIdentifier
            )
            Task {
                await syncGroupReminderPreferenceIfNeeded()
                await refreshDebugReminderCountIfNeeded()
            }
            updateAnalyticsPersonPropertiesIfNeeded()
        }
    }
    @Published var feedbackPreferences = UIFeedbackPreferences() {
        didSet {
            persistFeedbackPreferences()
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
            updateAnalyticsPersonPropertiesIfNeeded()
        }
    }

    @Published var selectedTemplateIDs: Set<String> = []
    @Published var pendingSignUpEmail = ""
    @Published var pendingSignUpUsername = ""
    @Published var pendingPasswordResetEmail = ""
    @Published var otpFlowMode: OTPFlowMode = .signup
    @Published var todayQuote: UIQuote = UIFixtures.dailyQuote
    @Published private(set) var authErrorMessage: String?
    @Published private(set) var authSuccessMessage: String?
    @Published private(set) var otpResendSecondsRemaining = 0
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

    var isGoogleAuthEnabled: Bool {
        dependencies.environment.oauthConfig.googleEnabled
    }

    var isAppleAuthEnabled: Bool {
        dependencies.environment.oauthConfig.appleEnabled
    }

    var profileDebugDiagnosticsText: String? {
        #if DEBUG
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown.bundle"
        let supabaseURL = dependencies.environment.supabaseConfig?.url
        let host = supabaseURL?.host ?? "supabase-unconfigured"
        let port = supabaseURL?.port.map(String.init) ?? ""
        let endpoint = port.isEmpty ? host : "\(host):\(port)"
        let namespace = dependencies.environment.storageNamespace
        return "\(bundleID) | \(endpoint) | \(namespace)"
        #else
        return nil
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
    private var replaceLocalHabitsTask: Task<Void, Never>?
    private var deletedHabitIDs = Set<UUID>()
    private let avatarUploadLimitBytes = 5 * 1024 * 1024
    private let avatarMaxDimension: CGFloat = 2048
    private let avatarMinDimension: CGFloat = 640
    private var passwordRecoverySource: PasswordRecoverySource = .onboarding
    private var otpResendCooldownsByKey: [String: Date] = [:]
    private var activeOTPResendKey: String?
    private var otpResendTimerTask: Task<Void, Never>?
    private var todayReloadTask: Task<Void, Never>?
    private var isLoadingTodayData = false
    private var pendingTodayDataReload = false
    private var pendingHabitToggleIDs = Set<UUID>()
    private var currentSessionUserID: UUID?
    private var postDeleteHabitSnapshot: [UIHabit]?
    private var streakByHabitID: [UUID: Int] = [:]
    private let sessionTracker: AppSessionAnalyticsTracker
    private let connectivityMonitor = NWPathMonitor()
    private let connectivityMonitorQueue = DispatchQueue(label: "com.sunnad.connectivity.monitor")

    init(dependencies: DependencyContainer, userDefaults: UserDefaults = .standard) {
        self.dependencies = dependencies
        self.userDefaults = userDefaults
        self.sessionTracker = AppSessionAnalyticsTracker(
            analytics: dependencies.analytics,
            consumeNotificationOpenSource: {
                dependencies.notificationInteractionTracker.consumePendingOpenSource()
            }
        )

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
            logger: dependencies.analyticsLogger,
            analytics: dependencies.analytics
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
        startConnectivityMonitoring()

        #if DEBUG
        applyDebugLaunchOverrides()
        #endif

        notificationPreferences = loadNotificationPreferences()
        feedbackPreferences = loadFeedbackPreferences()

        Task {
            await restoreAuthSessionIfNeeded()
            await loadTodayData()
        }
    }

    deinit {
        otpResendTimerTask?.cancel()
        todayReloadTask?.cancel()
        connectivityMonitor.cancel()
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
        guard let fallbackHabit = habits.first(where: { $0.id == habitID }) else {
            return nil
        }

        return Binding(
            get: { self.habits.first(where: { $0.id == habitID }) ?? fallbackHabit },
            set: { updated in
                guard !self.deletedHabitIDs.contains(habitID) else {
                    return
                }
                guard let dynamicIndex = self.habits.firstIndex(where: { $0.id == habitID }) else {
                    return
                }
                self.habits[dynamicIndex] = updated
                self.updateHabit(updated)
            }
        )
    }

    func moveOnboardingForward() {
        switch onboardingStep {
        case .welcome:
            dependencies.analytics.trackOnboardingStepCompleted(.welcome)
            onboardingStep = .templates
        case .templates:
            dependencies.analytics.trackOnboardingStepCompleted(.templates)
            onboardingStep = .notifications
        case .notifications:
            dependencies.analytics.trackOnboardingStepCompleted(.notifications)
            onboardingStep = .joinGroups
        case .joinGroups:
            dependencies.analytics.trackOnboardingStepCompleted(.joinGroups)
            completeAsGuest()
        case .signIn, .signUp, .otp:
            break
        }
    }

    func openSignIn() {
        clearAuthError()
        dependencies.analytics.trackOnboardingStepCompleted(.joinGroups)
        onboardingStep = .signIn
    }

    func openSignUp() {
        clearAuthError()
        dependencies.analytics.trackOnboardingStepCompleted(.joinGroups)
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
        dependencies.analytics.trackOnboardingStepCompleted(.templates)
        onboardingStep = .notifications
    }

    func enableOnboardingNotifications() {
        dependencies.analytics.trackOnboardingStepCompleted(.notifications)
        dependencies.requestLocalNotificationPermission()
        onboardingStep = .joinGroups
    }

    func skipOnboardingNotifications() {
        dependencies.analytics.trackOnboardingStepCompleted(.notifications)
        onboardingStep = .joinGroups
    }

    func completeAsGuest() {
        dependencies.analytics.trackOnboardingStepCompleted(.joinGroups)
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
                await syncSignedInSession(sessionUser, trigger: .auth, promotionMode: .none)
                markOnboardingCompleted()
                activeTab = .today
                dependencies.analytics.trackAuth(
                    kind: .signIn,
                    provider: .email,
                    status: .success
                )
            } catch {
                authSuccessMessage = nil
                authErrorMessage = error.localizedDescription
                dependencies.analyticsLogger.log(
                    .storageFailure,
                    metadata: ["scope": "auth_sign_in", "error": error.localizedDescription]
                )
                dependencies.analytics.trackAuth(
                    kind: .signIn,
                    provider: .email,
                    status: .failure,
                    reason: "error"
                )
            }
        }
    }

    func handleGoogleSignIn() {
        handleOAuthSignIn(using: .google, intent: .signIn, fromProfileSurface: false)
    }

    func handleGoogleSignUp() {
        handleOAuthSignIn(using: .google, intent: .signUp, fromProfileSurface: false)
    }

    func handleGoogleProfileSignIn() {
        handleOAuthSignIn(using: .google, intent: .signIn, fromProfileSurface: true)
    }

    func handleGoogleProfileSignUp() {
        handleOAuthSignIn(using: .google, intent: .signUp, fromProfileSurface: true)
    }

    func handleAppleSignIn() {
        handleOAuthSignIn(using: .apple, intent: .signIn, fromProfileSurface: false)
    }

    func handleAppleSignUp() {
        handleOAuthSignIn(using: .apple, intent: .signUp, fromProfileSurface: false)
    }

    func handleAppleProfileSignIn() {
        handleOAuthSignIn(using: .apple, intent: .signIn, fromProfileSurface: true)
    }

    func handleAppleProfileSignUp() {
        handleOAuthSignIn(using: .apple, intent: .signUp, fromProfileSurface: true)
    }

    func handleSignUp(email: String, username: String, password: String, method: String = "email") {
        Task {
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            do {
                let sessionUser = try await dependencies.authService.signUp(
                    email: normalizedEmail,
                    password: password,
                    username: normalizedUsername
                )
                authErrorMessage = nil
                authSuccessMessage = nil
                user = sessionUser.asUIUserState
                await syncSignedInSession(sessionUser, trigger: .auth, promotionMode: .signup)
                markOnboardingCompleted()
                activeTab = .today
                onboardingStep = .joinGroups
                dependencies.analytics.trackAuth(
                    kind: .signUp,
                    provider: .email,
                    status: .success
                )
            } catch {
                if case AuthServiceError.emailNotConfirmed = error {
                    pendingSignUpEmail = normalizedEmail
                    pendingSignUpUsername = normalizedUsername
                    otpFlowMode = .signup
                    activateOTPCooldown(flow: .signup, email: normalizedEmail)
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
                dependencies.analytics.trackAuth(
                    kind: .signUp,
                    provider: .email,
                    status: .failure,
                    reason: "error"
                )
            }
        }
    }

    func verifyOTP(code: String) {
        verifyOTP(code: code, fromProfileSurface: false)
    }

    func resendOTP() {
        resendOTP(fromProfileSurface: false)
    }

    func toggleTodayHabit(_ habitID: UUID, source: String = "today") {
        guard !pendingHabitToggleIDs.contains(habitID) else {
            return
        }
        guard let transaction = todayViewModel.beginHabitToggle(habitID) else {
            return
        }
        pendingHabitToggleIDs.insert(habitID)

        dependencies.analytics.trackHabit(
            .completionToggled(
                type: transaction.type,
                status: transaction.status,
                source: source
            )
        )
        if transaction.status == "completed" {
            dependencies.interactionFeedback.habitCompleted(hapticsEnabled: feedbackPreferences.hapticsEnabled)
        }

        Task { [weak self] in
            guard let self else { return }
            let didCommit = await todayViewModel.commitHabitToggle(transaction)
            if didCommit {
                scheduleTodayReload()
            } else {
                todayViewModel.rollbackHabitToggle(transaction)
            }
            pendingHabitToggleIDs.remove(habitID)
        }
    }

    func toggleHabit(_ habitID: UUID) {
        toggleTodayHabit(habitID, source: "groups")
    }

    func appDidBecomeActive() {
        sessionTracker.appDidBecomeActive()
    }

    func appDidEnterBackground() {
        sessionTracker.appDidEnterBackground()
    }

    func handleDhikrCounterIncrement(reachedTarget: Bool) {
        dependencies.interactionFeedback.dhikrIncremented(hapticsEnabled: feedbackPreferences.hapticsEnabled)
        guard reachedTarget else {
            return
        }
        dependencies.interactionFeedback.dhikrTargetReached(
            hapticsEnabled: feedbackPreferences.hapticsEnabled,
            soundsEnabled: feedbackPreferences.soundsEnabled
        )
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
            dependencies.analytics.trackHabit(
                .created(
                    type: template.isDhikr ? "dhikr" : "binary",
                    scheduleType: UIHabitSchedule.daily.rawValue,
                    hasReminder: false,
                    targetCount: template.isDhikr ? 33 : 0
                )
            )
        }
    }

    func addCustomHabit(
        name: String,
        iconSystemName: String,
        category: HabitCategory,
        categoryCustom: String?,
        schedule: UIHabitSchedule,
        weekdays: Set<Int>,
        reminderTime: Date?,
        hasDhikrCounter: Bool
    ) {
        let habit = UIHabit(
            customTitle: name,
            iconSystemName: iconSystemName,
            category: category,
            categoryCustom: categoryCustom,
            completedToday: false,
            streak: 0,
            schedule: schedule,
            weekdays: weekdays,
            reminderTime: reminderTime,
            isDhikr: hasDhikrCounter,
            dhikrCount: 0,
            dhikrTarget: hasDhikrCounter ? 33 : 0
        )

        deletedHabitIDs.remove(habit.id)
        habits.append(habit)
        persistHabit(habit)
        dependencies.analytics.trackHabit(
            .created(
                type: hasDhikrCounter ? "dhikr" : "binary",
                scheduleType: schedule.rawValue,
                hasReminder: reminderTime != nil,
                targetCount: hasDhikrCounter ? habit.dhikrTarget : 0
            )
        )
    }

    func updateHabit(_ habit: UIHabit) {
        guard !deletedHabitIDs.contains(habit.id) else {
            return
        }
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else {
            return
        }

        let previous = habits[index]
        let changedFields = changedHabitFields(from: previous, to: habit)
        let editedFields = changedFields.filter {
            $0 != "dhikr_count" && $0 != "dhikr_counts" && $0 != "selected_dhikr_key"
        }

        habits[index] = habit
        persistHabit(habit)

        if !editedFields.isEmpty {
            dependencies.analytics.trackHabit(.edited(changedFields: editedFields))
        }

        if previous.reminderTime == nil, habit.reminderTime != nil {
            dependencies.analytics.trackHabit(.reminderToggled(status: "enabled"))
        } else if previous.reminderTime != nil, habit.reminderTime == nil {
            dependencies.analytics.trackHabit(.reminderToggled(status: "disabled"))
        }

        if habit.isDhikr {
            let delta = habit.dhikrCount - previous.dhikrCount
            if delta > 0 {
                dependencies.analytics.trackHabit(
                    .counterIncremented(
                        delta: delta,
                        count: habit.dhikrCount,
                        target: max(habit.dhikrTarget, 1)
                    )
                )
            }
        }
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
        dependencies.interactionFeedback.destructiveAction(hapticsEnabled: feedbackPreferences.hapticsEnabled)
        if case .habitDetail(let selectedID) = rootSheet, selectedID == habitID {
            rootSheet = nil
        }
        let deletedHabitType = habits.first(where: { $0.id == habitID })?.isDhikr == true ? "dhikr" : "binary"
        deletedHabitIDs.insert(habitID)
        cancelAllPersistTasks()
        habits.removeAll(where: { $0.id == habitID })

        Task {
            do {
                try await dependencies.habitsRepository.deleteHabit(id: habitID)
                await groupsViewModel.updateHabitSharing(habitID: habitID, sharedGroupIDs: [])
                await dependencies.reminderScheduler.removeReminder(habitID: habitID)
                dependencies.analytics.trackHabit(.deleted(type: deletedHabitType))
                await loadTodayData()
            } catch {
                dependencies.analyticsLogger.log(.storageFailure, metadata: ["scope": "delete_habit", "error": error.localizedDescription])
            }
        }
    }

    func saveCurrentQuote() {
        Task {
            let didSave = await todayViewModel.saveCurrentQuote()
            if didSave {
                dependencies.analytics.trackQuote(.saved)
            }
            await profileViewModel.load()
        }
    }

    func openQuoteOfDay() {
        dependencies.analytics.trackQuote(.opened)
        rootSheet = .quoteOfDay
    }

    func trackQuoteShared(channel: String?) {
        dependencies.analytics.trackQuote(.shared(channel: channel))
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

    func openProfileEditor() {
        guard !user.isGuest else {
            return
        }
        clearAuthError()
        fullScreen = .editProfile
    }

    func clearAuthError() {
        authErrorMessage = nil
        authSuccessMessage = nil
    }

    func submitProfileUsername(_ username: String) {
        Task {
            do {
                let sessionUser = try await dependencies.authService.updateUsername(username)
                user = sessionUser.asUIUserState
                authErrorMessage = nil
                authSuccessMessage = L10n.t("profile.edit.saved")
                await refreshProfileFromRemote(showErrors: false)
            } catch {
                authSuccessMessage = nil
                authErrorMessage = error.localizedDescription
                dependencies.analyticsLogger.log(
                    .storageFailure,
                    metadata: ["scope": "profile_update_username", "error": error.localizedDescription]
                )
            }
        }
    }

    func uploadProfileAvatar(data: Data, mimeType: String) {
        Task {
            guard let compressed = compressedAvatarPayload(from: data, preferredMimeType: mimeType) else {
                authSuccessMessage = nil
                authErrorMessage = L10n.t("profile.edit.avatar.invalid")
                return
            }

            do {
                let previousAvatarURL = user.avatarURL
                let sessionUser = try await dependencies.authService.uploadAvatar(
                    data: compressed.data,
                    mimeType: compressed.mimeType
                )
                user = sessionUser.asUIUserState
                authErrorMessage = nil
                authSuccessMessage = L10n.t("profile.edit.avatar.updated")
                await AvatarImageCache.shared.invalidate(url: previousAvatarURL)
                Task {
                    await AvatarImageCache.shared.preload(url: self.user.avatarURL)
                }
                await refreshProfileFromRemote(showErrors: false)
            } catch {
                authSuccessMessage = nil
                authErrorMessage = error.localizedDescription
                dependencies.analyticsLogger.log(
                    .storageFailure,
                    metadata: ["scope": "profile_upload_avatar", "error": error.localizedDescription]
                )
            }
        }
    }

    func removeProfileAvatar() {
        Task {
            do {
                let previousAvatarURL = user.avatarURL
                let sessionUser = try await dependencies.authService.removeAvatar()
                user = sessionUser.asUIUserState
                authErrorMessage = nil
                authSuccessMessage = L10n.t("profile.edit.avatar.removed")
                await AvatarImageCache.shared.invalidate(url: previousAvatarURL)
                await refreshProfileFromRemote(showErrors: false)
            } catch {
                authSuccessMessage = nil
                authErrorMessage = error.localizedDescription
                dependencies.analyticsLogger.log(
                    .storageFailure,
                    metadata: ["scope": "profile_remove_avatar", "error": error.localizedDescription]
                )
            }
        }
    }

    func openOnboardingForgotPassword(prefill identifier: String) {
        pendingPasswordResetEmail = resolveEmailFromIdentifier(identifier)
        passwordRecoverySource = .onboarding
        clearAuthError()
        fullScreen = .forgotPasswordOnboarding
    }

    func openProfileForgotPassword(prefill identifier: String) {
        pendingPasswordResetEmail = resolveEmailFromIdentifier(identifier)
        passwordRecoverySource = .profile
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

    func closeOnboardingForgotPasswordOTP() {
        clearAuthError()
        fullScreen = .forgotPasswordOnboarding
    }

    func closeProfileForgotPasswordOTP() {
        clearAuthError()
        fullScreen = .forgotPasswordProfile
    }

    func submitPasswordResetRequest(email: String) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedEmail.contains("@") else {
            authSuccessMessage = nil
            authErrorMessage = AuthServiceError.invalidCredentials.localizedDescription
            return
        }
        pendingPasswordResetEmail = normalizedEmail

        Task {
            do {
                try await dependencies.authService.requestPasswordReset(
                    email: normalizedEmail,
                    redirectTo: dependencies.environment.authRedirectURL
                )
                userDefaults.set(true, forKey: LocalStateKeys.pendingPasswordRecovery)
                otpFlowMode = .recovery
                activateOTPCooldown(flow: .recovery, email: normalizedEmail)
                authErrorMessage = nil
                authSuccessMessage = L10n.t("auth.forgot_password.sent")
                fullScreen = passwordRecoverySource == .onboarding
                    ? .forgotPasswordOTPOnboarding
                    : .forgotPasswordOTPProfile
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
                activeTab = .today
                userDefaults.set(false, forKey: LocalStateKeys.pendingPasswordRecovery)
                await syncSignedInSession(sessionUser, trigger: .auth, promotionMode: .none)
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
        sessionTracker.markDeepLinkOpened()
        guard isPotentialAuthCallbackURL(url) else {
            return
        }

        let hasAuthPayload = Self.hasCallbackAuthPayload(url)
        guard hasAuthPayload else {
            authSuccessMessage = nil
            authErrorMessage = AuthServiceError.invalidRecoveryLink.localizedDescription
            dependencies.analyticsLogger.log(
                .storageFailure,
                metadata: ["scope": "auth_callback_missing_payload", "reason": "missing_auth_payload"]
            )
            return
        }

        let recoveryPending = userDefaults.bool(forKey: LocalStateKeys.pendingPasswordRecovery)
        let isRecoveryCallback = Self.isRecoveryCallbackURL(url)
        let shouldOpenRecoveryPassword = isRecoveryCallback || (recoveryPending && hasAuthPayload)

        Task {
            do {
                guard let sessionUser = try await dependencies.authService.handleAuthCallback(url: url) else {
                    return
                }

                authErrorMessage = nil
                authSuccessMessage = nil
                user = sessionUser.asUIUserState
                if shouldOpenRecoveryPassword {
                    userDefaults.set(false, forKey: LocalStateKeys.pendingPasswordRecovery)
                    pendingPasswordResetEmail = sessionUser.email ?? pendingPasswordResetEmail
                    otpFlowMode = .recovery
                    fullScreen = .changePassword
                } else {
                    fullScreen = nil
                }
                let promotionMode = resolvePromotionModeForAuthCallback(
                    url: url,
                    shouldOpenRecoveryPassword: shouldOpenRecoveryPassword
                )
                await syncSignedInSession(sessionUser, trigger: .auth, promotionMode: promotionMode)
                clearPendingOAuthIntent()
                markOnboardingCompleted()
                activeTab = .today
            } catch {
                clearPendingOAuthIntent()
                authSuccessMessage = nil
                authErrorMessage = error.localizedDescription
                if shouldOpenRecoveryPassword {
                    fullScreen = passwordRecoverySource == .profile
                        ? .forgotPasswordOTPProfile
                        : .forgotPasswordOTPOnboarding
                }
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
                await syncSignedInSession(sessionUser, trigger: .auth, promotionMode: .none)
                markOnboardingCompleted()
                fullScreen = nil
                dependencies.analytics.trackAuth(
                    kind: .signIn,
                    provider: .email,
                    status: .success
                )
            } catch {
                authSuccessMessage = nil
                authErrorMessage = error.localizedDescription
                dependencies.analyticsLogger.log(
                    .storageFailure,
                    metadata: ["scope": "auth_profile_sign_in", "error": error.localizedDescription]
                )
                dependencies.analytics.trackAuth(
                    kind: .signIn,
                    provider: .email,
                    status: .failure,
                    reason: "error"
                )
            }
        }
    }

    func handleProfileSignUp(email: String, username: String, password: String, method: String = "email") {
        Task {
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            do {
                let sessionUser = try await dependencies.authService.signUp(
                    email: normalizedEmail,
                    password: password,
                    username: normalizedUsername
                )
                authErrorMessage = nil
                authSuccessMessage = nil
                user = sessionUser.asUIUserState
                await syncSignedInSession(sessionUser, trigger: .auth, promotionMode: .signup)
                markOnboardingCompleted()
                fullScreen = nil
                dependencies.analytics.trackAuth(
                    kind: .signUp,
                    provider: .email,
                    status: .success
                )
            } catch {
                if case AuthServiceError.emailNotConfirmed = error {
                    pendingSignUpEmail = normalizedEmail
                    pendingSignUpUsername = normalizedUsername
                    otpFlowMode = .signup
                    activateOTPCooldown(flow: .signup, email: normalizedEmail)
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
                dependencies.analytics.trackAuth(
                    kind: .signUp,
                    provider: .email,
                    status: .failure,
                    reason: "error"
                )
            }
        }
    }

    func verifyProfileOTP(code: String) {
        verifyOTP(code: code, fromProfileSurface: true)
    }

    func resendProfileOTP() {
        resendOTP(fromProfileSurface: true)
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

            dependencies.analytics.reset()

            authErrorMessage = nil
            authSuccessMessage = nil
            user = .guest
            currentSessionUserID = nil
            await OneSignalBridge.shared.logout()
            await dependencies.syncCoordinator.setSignedInUserID(nil)
            await loadTodayData()
        }
    }

    func deleteData() {
        Task {
            postDeleteHabitSnapshot = nil
            cancelAllPersistTasks()
            if case .habitDetail = rootSheet {
                rootSheet = nil
            }
            await clearLocalData()
            selectedTemplateIDs = []
            pendingSignUpEmail = ""
            pendingSignUpUsername = ""
            await loadTodayData()
        }
    }

    func deleteAccount() {
        let preservedHabits = habits
        let preservedTodayHabits = todayHabitsData
        Task {
            postDeleteHabitSnapshot = preservedHabits
            todayReloadTask?.cancel()
            pendingTodayDataReload = false
            currentSessionUserID = nil
            do {
                try await dependencies.authService.deleteAccount()
                try? await dependencies.authService.signOut()
            } catch {
                authErrorMessage = error.localizedDescription
                dependencies.analyticsLogger.log(
                    .storageFailure,
                    metadata: ["scope": "auth_delete_account", "error": error.localizedDescription]
                )
                return
            }

            dependencies.analytics.reset()

            pendingPasswordResetEmail = ""
            otpFlowMode = .signup
            user = .guest
            currentSessionUserID = nil
            await OneSignalBridge.shared.logout()
            authErrorMessage = nil
            authSuccessMessage = nil
            markOnboardingCompleted()
            rootSheet = nil
            fullScreen = nil
            await dependencies.syncCoordinator.setSignedInUserID(nil)
            await profileViewModel.load()
            habits = preservedHabits
            todayHabitsData = preservedTodayHabits
            trackStreakTransitions(using: preservedTodayHabits)
            activeTab = .profile
        }
    }

    func trackScreen(_ screen: AnalyticsScreen) {
        dependencies.analytics.trackScreen(screen)
    }

    func trackGroupOpened() {
        dependencies.analytics.trackGroup(.opened)
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
        dependencies.interactionFeedback.destructiveAction(hapticsEnabled: feedbackPreferences.hapticsEnabled)
        Task {
            await groupsViewModel.leaveGroup(groupID)
        }
    }

    func deleteGroup(_ groupID: UUID) {
        dependencies.interactionFeedback.destructiveAction(hapticsEnabled: feedbackPreferences.hapticsEnabled)
        Task {
            await groupsViewModel.deleteGroup(groupID)
        }
    }

    func kickMember(groupID: UUID, memberID: UUID) {
        Task {
            await groupsViewModel.kickMember(groupID: groupID, memberID: memberID)
        }
    }

    func setGroupProgressDisplayMode(groupID: UUID, mode: GroupProgressDisplayMode) {
        Task {
            await groupsViewModel.setProgressDisplayMode(groupID: groupID, mode: mode)
        }
    }

    func renameGroup(groupID: UUID, name: String) {
        Task {
            await groupsViewModel.renameGroup(groupID: groupID, name: name)
        }
    }

    func setGroupJoinLock(groupID: UUID, locked: Bool) {
        Task {
            await groupsViewModel.setGroupJoinLock(groupID: groupID, locked: locked)
        }
    }

    func rotateGroupInviteCode(groupID: UUID) {
        Task {
            await groupsViewModel.rotateInviteCode(groupID: groupID)
        }
    }

    func refreshGroups() async {
        await groupsViewModel.refresh()
    }

    func refreshGroup(_ groupID: UUID) async {
        await groupsViewModel.refreshGroup(groupID: groupID)
    }

    func refreshProfile() async {
        await refreshProfileFromRemote(showErrors: true)
    }

    func sendGroupNudge(groupID: UUID, memberID: UUID, habitID: UUID) async -> GroupNudgeStatus {
        let status = await groupsViewModel.sendNudge(groupID: groupID, memberID: memberID, habitID: habitID)
        if status == .sent {
            dependencies.interactionFeedback.groupNudgeSent(hapticsEnabled: feedbackPreferences.hapticsEnabled)
        }
        return status
    }

    func trackGroupMemberProgressViewed(memberScope: String, sharedHabitsCount: Int) {
        dependencies.analytics.trackGroupInsight(
            .memberProgressViewed(
                memberScope: memberScope,
                sharedHabitsCount: sharedHabitsCount
            )
        )
    }

    private func handleOAuthSignIn(
        using provider: OAuthProvider,
        intent: OAuthIntent,
        fromProfileSurface: Bool
    ) {
        switch provider {
        case .google where !dependencies.environment.oauthConfig.googleEnabled:
            authErrorMessage = AuthServiceError.providerUnavailable("Google").localizedDescription
            return
        case .apple where !dependencies.environment.oauthConfig.appleEnabled:
            authErrorMessage = AuthServiceError.providerUnavailable("Apple").localizedDescription
            return
        default:
            break
        }

        Task {
            do {
                setPendingOAuthIntent(intent)
                let sessionUser: SessionUser
                switch provider {
                case .google:
                    sessionUser = try await dependencies.authService.signInWithGoogle()
                case .apple:
                    sessionUser = try await dependencies.authService.signInWithApple()
                }
                authErrorMessage = nil
                authSuccessMessage = nil
                user = sessionUser.asUIUserState
                let promotionMode: GuestPromotionMode = intent == .signUp ? .signup : .none
                await syncSignedInSession(sessionUser, trigger: .auth, promotionMode: promotionMode)
                clearPendingOAuthIntent()
                markOnboardingCompleted()
                activeTab = .today
                dependencies.analytics.trackAuth(
                    kind: intent == .signUp ? .signUp : .signIn,
                    provider: provider == .google ? .google : .apple,
                    status: .success
                )
                if fromProfileSurface {
                    fullScreen = nil
                }
            } catch {
                clearPendingOAuthIntent()
                authSuccessMessage = nil
                authErrorMessage = error.localizedDescription
                dependencies.analyticsLogger.log(
                    .storageFailure,
                    metadata: ["scope": "auth_oauth_\(provider.scope)", "error": error.localizedDescription]
                )
                dependencies.analytics.trackAuth(
                    kind: intent == .signUp ? .signUp : .signIn,
                    provider: provider == .google ? .google : .apple,
                    status: .failure,
                    reason: "error"
                )
            }
        }
    }

    private func verifyOTP(code: String, fromProfileSurface: Bool) {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = currentOTPEmail().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else {
            authErrorMessage = AuthServiceError.invalidCredentials.localizedDescription
            return
        }

        Task {
            do {
                let sessionUser: SessionUser
                switch otpFlowMode {
                case .signup:
                    sessionUser = try await dependencies.authService.verifyEmailOTP(
                        email: email,
                        code: normalizedCode
                    )
                    markOnboardingCompleted()
                    activeTab = .today
                    onboardingStep = .joinGroups
                    fullScreen = nil
                case .recovery:
                    sessionUser = try await dependencies.authService.verifyRecoveryCode(
                        email: email,
                        code: normalizedCode
                    )
                    userDefaults.set(true, forKey: LocalStateKeys.pendingPasswordRecovery)
                    fullScreen = .changePassword
                }

                authErrorMessage = nil
                authSuccessMessage = nil
                user = sessionUser.asUIUserState
                let promotionMode: GuestPromotionMode = otpFlowMode == .signup ? .signup : .none
                await syncSignedInSession(sessionUser, trigger: .auth, promotionMode: promotionMode)
                if otpFlowMode == .signup {
                    dependencies.analytics.trackAuth(
                        kind: .signUp,
                        provider: .email,
                        status: .success
                    )
                }
            } catch {
                authSuccessMessage = nil
                authErrorMessage = error.localizedDescription
                dependencies.analyticsLogger.log(
                    .storageFailure,
                    metadata: [
                        "scope": fromProfileSurface ? "auth_profile_verify_otp" : "auth_verify_otp",
                        "flow": otpFlowMode.rawValue,
                        "error": error.localizedDescription
                    ]
                )
                if otpFlowMode == .signup {
                    dependencies.analytics.trackAuth(
                        kind: .signUp,
                        provider: .email,
                        status: .failure,
                        reason: "error"
                    )
                }
            }
        }
    }

    private func resendOTP(fromProfileSurface: Bool) {
        guard otpResendSecondsRemaining <= 0 else {
            return
        }

        let email = currentOTPEmail().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else {
            authErrorMessage = AuthServiceError.invalidCredentials.localizedDescription
            return
        }

        Task {
            do {
                switch otpFlowMode {
                case .signup:
                    try await dependencies.authService.resendSignUpOTP(
                        email: email,
                        redirectTo: dependencies.environment.authRedirectURL
                    )
                case .recovery:
                    try await dependencies.authService.resendRecoveryCode(
                        email: email,
                        redirectTo: dependencies.environment.authRedirectURL
                    )
                }
                activateOTPCooldown(flow: otpFlowMode, email: email)
                authErrorMessage = nil
                authSuccessMessage = L10n.t("auth.otp.resent")
            } catch {
                if case AuthServiceError.rateLimited = error {
                    activateOTPCooldown(flow: otpFlowMode, email: email)
                }
                authSuccessMessage = nil
                authErrorMessage = error.localizedDescription
                dependencies.analyticsLogger.log(
                    .storageFailure,
                    metadata: [
                        "scope": fromProfileSurface ? "auth_profile_resend_otp" : "auth_resend_otp",
                        "flow": otpFlowMode.rawValue,
                        "error": error.localizedDescription
                    ]
                )
            }
        }
    }

    private func currentOTPEmail() -> String {
        switch otpFlowMode {
        case .signup:
            return pendingSignUpEmail
        case .recovery:
            return pendingPasswordResetEmail
        }
    }

    private func activateOTPCooldown(flow: OTPFlowMode, email: String) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty else {
            otpResendSecondsRemaining = 0
            return
        }

        let key = "\(flow.rawValue):\(normalizedEmail)"
        let deadline = Date().addingTimeInterval(TimeInterval(dependencies.environment.otpResendCooldownSeconds))
        otpResendCooldownsByKey[key] = deadline
        activeOTPResendKey = key
        updateOTPResendCountdown()
        ensureOTPResendTimerRunning()
    }

    private func ensureOTPResendTimerRunning() {
        guard otpResendTimerTask == nil else {
            return
        }

        otpResendTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                await MainActor.run {
                    self?.updateOTPResendCountdown()
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func updateOTPResendCountdown() {
        let now = Date()
        otpResendCooldownsByKey = otpResendCooldownsByKey.filter { $0.value > now }

        guard let key = activeOTPResendKey, let deadline = otpResendCooldownsByKey[key] else {
            otpResendSecondsRemaining = 0
            if otpResendCooldownsByKey.isEmpty {
                otpResendTimerTask?.cancel()
                otpResendTimerTask = nil
            }
            return
        }

        otpResendSecondsRemaining = max(Int(ceil(deadline.timeIntervalSince(now))), 0)
    }

    private func loadNotificationPreferences() -> UINotificationPreferences {
        let hasStoredHabit = userDefaults.object(forKey: LocalStateKeys.habitRemindersEnabled) != nil
        let hasStoredQuote = userDefaults.object(forKey: LocalStateKeys.quoteRemindersEnabled) != nil
        let hasStoredGroup = userDefaults.object(forKey: LocalStateKeys.groupRemindersEnabled) != nil

        return UINotificationPreferences(
            habitReminders: hasStoredHabit
                ? userDefaults.bool(forKey: LocalStateKeys.habitRemindersEnabled)
                : true,
            quoteReminder: hasStoredQuote
                ? userDefaults.bool(forKey: LocalStateKeys.quoteRemindersEnabled)
                : true,
            groupReminders: hasStoredGroup
                ? userDefaults.bool(forKey: LocalStateKeys.groupRemindersEnabled)
                : true
        )
    }

    private func loadFeedbackPreferences() -> UIFeedbackPreferences {
        let hasStoredHaptics = userDefaults.object(forKey: LocalStateKeys.hapticsEnabled) != nil
        let hasStoredSounds = userDefaults.object(forKey: LocalStateKeys.soundsEnabled) != nil

        return UIFeedbackPreferences(
            hapticsEnabled: hasStoredHaptics
                ? userDefaults.bool(forKey: LocalStateKeys.hapticsEnabled)
                : true,
            soundsEnabled: hasStoredSounds
                ? userDefaults.bool(forKey: LocalStateKeys.soundsEnabled)
                : false
        )
    }

    private func persistNotificationPreferences() {
        userDefaults.set(notificationPreferences.habitReminders, forKey: LocalStateKeys.habitRemindersEnabled)
        userDefaults.set(notificationPreferences.quoteReminder, forKey: LocalStateKeys.quoteRemindersEnabled)
        userDefaults.set(notificationPreferences.groupReminders, forKey: LocalStateKeys.groupRemindersEnabled)
    }

    private func persistFeedbackPreferences() {
        userDefaults.set(feedbackPreferences.hapticsEnabled, forKey: LocalStateKeys.hapticsEnabled)
        userDefaults.set(feedbackPreferences.soundsEnabled, forKey: LocalStateKeys.soundsEnabled)
    }

    private func syncGroupReminderPreferenceIfNeeded() async {
        guard let currentSessionUserID else {
            return
        }
        await dependencies.deviceTokenSyncService.setGroupRemindersEnabled(
            notificationPreferences.groupReminders,
            for: currentSessionUserID
        )
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
                guard let self else { return }
                self.dependencies.syncQuoteReminders(
                    enabled: self.notificationPreferences.quoteReminder,
                    locale: self.language.localeIdentifier
                )
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

        groupsViewModel.$groups
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateAnalyticsPersonPropertiesIfNeeded()
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

    private func scheduleTodayReload() {
        todayReloadTask?.cancel()
        todayReloadTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else {
                return
            }
            await self?.loadTodayData()
        }
    }

    private func loadTodayData() async {
        if isLoadingTodayData {
            pendingTodayDataReload = true
            return
        }
        isLoadingTodayData = true
        defer {
            isLoadingTodayData = false
            if pendingTodayDataReload {
                pendingTodayDataReload = false
                Task { [weak self] in
                    await self?.loadTodayData()
                }
            }
        }

        let preloadedHistories = await reloadAllHabitsFromStorage()
        if user.isGuest, habits.isEmpty, let snapshot = postDeleteHabitSnapshot, !snapshot.isEmpty {
            habits = snapshot
            todayHabitsData = snapshot
        }
        await todayViewModel.loadToday(preloadedHistories: preloadedHistories)
        trackStreakTransitions(using: todayViewModel.habits)
        await profileViewModel.load()
        dependencies.syncHabitReminders(enabled: notificationPreferences.habitReminders)
        dependencies.syncQuoteReminders(enabled: notificationPreferences.quoteReminder, locale: language.localeIdentifier)
        if !user.isGuest {
            await syncGroupReminderPreferenceIfNeeded()
            await dependencies.syncCoordinator.runSyncCycle(trigger: .foreground)
            await groupsViewModel.refresh()
        }
        updateAnalyticsPersonPropertiesIfNeeded()
        await refreshDebugReminderCountIfNeeded()
    }

    @discardableResult
    private func reloadAllHabitsFromStorage() async -> [UUID: [HabitCompletion]]? {
        do {
            let today = Date()
            let domainHabits = try await dependencies.habitsRepository.fetchHabits(includeArchived: false)
            var mapped: [UIHabit] = []
            var marksByHabit: [UUID: [Bool]] = [:]
            var historiesByHabitID: [UUID: [HabitCompletion]] = [:]
            mapped.reserveCapacity(domainHabits.count)

            for habit in domainHabits {
                let completion = try await dependencies.completionsRepository.fetchCompletion(
                    habitID: habit.id,
                    on: today,
                    calendar: .current,
                    timeZone: .current
                ) ?? HabitCompletion(habitID: habit.id, dayDate: today, value: 0)

                let history = try await dependencies.completionsRepository.fetchCompletions(for: habit.id)
                historiesByHabitID[habit.id] = history
                let streak = StreakCalculator.streak(for: habit, completions: history, asOf: today, referenceDate: today)
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
            return historiesByHabitID
        } catch {
            dependencies.analyticsLogger.log(.storageFailure, metadata: ["scope": "reload_habits", "error": error.localizedDescription])
            return nil
        }
    }

    private func clearLocalData() async {
        do {
            try await dependencies.clearLocalDataForCurrentScope()

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
        guard !deletedHabitIDs.contains(habit.id) else {
            return
        }
        persistTasks[habit.id]?.cancel()
        persistTasks[habit.id] = Task { @MainActor [weak self] in
            guard let self else { return }
            guard !self.deletedHabitIDs.contains(habit.id) else {
                self.persistTasks[habit.id] = nil
                return
            }
            let initialOwnerScope = self.dependencies.ownerScopeResolver.currentOwnerScopeRawValue
            var domain = habit.asDomainHabit()

            if let index = self.habits.firstIndex(where: { $0.id == habit.id }) {
                domain.sortOrder = index
            }

            do {
                guard self.dependencies.ownerScopeResolver.currentOwnerScopeRawValue == initialOwnerScope else {
                    self.persistTasks[habit.id] = nil
                    return
                }
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
                    guard self.dependencies.ownerScopeResolver.currentOwnerScopeRawValue == initialOwnerScope else {
                        self.persistTasks[habit.id] = nil
                        return
                    }
                    try await self.dependencies.completionsRepository.upsertCompletion(
                        completion,
                        calendar: .current,
                        timeZone: .current
                    )
                }

                if Task.isCancelled {
                    return
                }

                guard self.dependencies.ownerScopeResolver.currentOwnerScopeRawValue == initialOwnerScope else {
                    self.persistTasks[habit.id] = nil
                    return
                }
                await self.loadTodayData()
            } catch is CancellationError {
                self.persistTasks[habit.id] = nil
                return
            } catch {
                self.dependencies.analyticsLogger.log(.storageFailure, metadata: ["scope": "save_habit", "error": error.localizedDescription])
            }

            self.persistTasks[habit.id] = nil
        }
    }

    private func changedHabitFields(from oldHabit: UIHabit, to newHabit: UIHabit) -> [String] {
        var fields: [String] = []

        if oldHabit.displayTitle != newHabit.displayTitle {
            fields.append("name")
        }
        if oldHabit.iconSystemName != newHabit.iconSystemName {
            fields.append("icon")
        }
        if oldHabit.category != newHabit.category {
            fields.append("category")
        }
        if oldHabit.schedule != newHabit.schedule {
            fields.append("schedule_type")
        }
        if oldHabit.weekdays != newHabit.weekdays {
            fields.append("weekdays")
        }
        if normalizedReminderMinutes(oldHabit.reminderTime) != normalizedReminderMinutes(newHabit.reminderTime) {
            fields.append("reminder_time")
        }
        if (oldHabit.reminderTime == nil) != (newHabit.reminderTime == nil) {
            fields.append("reminder_enabled")
        }
        if oldHabit.dhikrTarget != newHabit.dhikrTarget {
            fields.append("target")
        }
        if oldHabit.dhikrCount != newHabit.dhikrCount {
            fields.append("dhikr_count")
        }
        if oldHabit.selectedDhikrKey != newHabit.selectedDhikrKey {
            fields.append("selected_dhikr_key")
        }
        if oldHabit.dhikrCountsByKey != newHabit.dhikrCountsByKey {
            fields.append("dhikr_counts")
        }

        return fields
    }

    private func normalizedReminderMinutes(_ date: Date?) -> Int? {
        guard let date else { return nil }
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else {
            return nil
        }
        return (hour * 60) + minute
    }

    private func markOnboardingCompleted() {
        userDefaults.set(true, forKey: LocalStateKeys.onboardingCompleted)
        showsOnboarding = false
    }

    private func compressedAvatarPayload(
        from data: Data,
        preferredMimeType: String
    ) -> (data: Data, mimeType: String)? {
        guard let image = UIImage(data: data) else {
            return nil
        }

        let normalizedMimeType = normalizedAvatarMimeType(
            preferredMimeType: preferredMimeType,
            originalData: data
        )
        if data.count <= avatarUploadLimitBytes {
            return (data, normalizedMimeType)
        }

        if let pngData = image.pngData(), pngData.count <= avatarUploadLimitBytes {
            return (pngData, "image/png")
        }

        var targetMaxDimension = min(max(image.size.width, image.size.height), avatarMaxDimension)
        while targetMaxDimension >= avatarMinDimension {
            guard let resized = resizedAvatarImage(image, maxDimension: targetMaxDimension) else {
                break
            }

            if let losslessResized = resized.pngData(), losslessResized.count <= avatarUploadLimitBytes {
                return (losslessResized, "image/png")
            }

            if let highQualityJPEG = resized.jpegData(compressionQuality: 0.95),
               highQualityJPEG.count <= avatarUploadLimitBytes {
                return (highQualityJPEG, "image/jpeg")
            }

            targetMaxDimension *= 0.8
        }

        for quality in stride(from: 0.92, through: 0.72, by: -0.05) {
            if let jpegData = image.jpegData(compressionQuality: quality),
               jpegData.count <= avatarUploadLimitBytes {
                return (jpegData, "image/jpeg")
            }
        }

        return nil
    }

    private func restoreAuthSessionIfNeeded() async {
        if let sessionUser = await dependencies.authService.currentUser() {
            authErrorMessage = nil
            authSuccessMessage = nil
            user = sessionUser.asUIUserState
            await syncSignedInSession(sessionUser, trigger: .restore, promotionMode: .none)
            markOnboardingCompleted()
            dependencies.analyticsLogger.log(.syncFinished, metadata: ["scope": "auth_restore", "status": "restored"])
        } else {
            currentSessionUserID = nil
            await dependencies.syncCoordinator.setSignedInUserID(nil)
            await OneSignalBridge.shared.logout()
            dependencies.analyticsLogger.log(.syncFinished, metadata: ["scope": "auth_restore", "status": "no_session"])
        }
    }

    private func syncSignedInSession(
        _ sessionUser: SessionUser,
        trigger: SyncTrigger,
        promotionMode: GuestPromotionMode
    ) async {
        postDeleteHabitSnapshot = nil
        let activeSessionUserID = sessionUser.id
        if promotionMode == .signup {
            await settleLocalHabitPersistenceBeforePromotion()
            await dependencies.syncCoordinator.promoteGuestDataIfNeeded(to: activeSessionUserID)
        }
        currentSessionUserID = activeSessionUserID
        let oneSignalAppID = dependencies.environment.oneSignalAppID
        let oneSignalAppGroupID = dependencies.environment.oneSignalAppGroupID
        Task { [weak self] in
            guard let self else { return }
            await OneSignalBridge.shared.configure(
                appID: oneSignalAppID,
                appGroupID: oneSignalAppGroupID
            )
            await OneSignalBridge.shared.login(externalID: activeSessionUserID.uuidString)
            guard self.currentSessionUserID == activeSessionUserID else { return }
            await self.syncGroupReminderPreferenceIfNeeded()
        }
        await dependencies.deviceTokenSyncService.syncCurrentDeviceToken(for: activeSessionUserID)
        await dependencies.deviceTokenSyncService.setGroupRemindersEnabled(
            notificationPreferences.groupReminders,
            for: activeSessionUserID
        )
        await dependencies.syncCoordinator.setSignedInUserID(activeSessionUserID)
        await dependencies.syncCoordinator.promoteLocalDataIfNeeded()
        await dependencies.syncCoordinator.runSyncCycle(trigger: trigger)
        guard currentSessionUserID == activeSessionUserID else { return }
        let histories = await reloadAllHabitsFromStorage()
        await todayViewModel.loadToday(preloadedHistories: histories)
        guard currentSessionUserID == activeSessionUserID else { return }
        trackStreakTransitions(using: todayViewModel.habits)
        await profileViewModel.load()
        await groupsViewModel.refresh()
        Task {
            await AvatarImageCache.shared.preload(url: self.user.avatarURL)
        }
        guard currentSessionUserID == activeSessionUserID else { return }
        identifySignedInUser(sessionUser)
    }

    private func refreshProfileFromRemote(showErrors: Bool) async {
        guard !user.isGuest else { return }

        do {
            let previousAvatarURL = user.avatarURL
            let sessionUser = try await dependencies.authService.fetchProfile()
            user = sessionUser.asUIUserState
            if previousAvatarURL != user.avatarURL {
                await AvatarImageCache.shared.invalidate(url: previousAvatarURL)
            }
            Task {
                await AvatarImageCache.shared.preload(url: self.user.avatarURL)
            }
            await profileViewModel.load()
            if showErrors {
                authErrorMessage = nil
            }
        } catch {
            if showErrors {
                authErrorMessage = error.localizedDescription
            }
            dependencies.analyticsLogger.log(
                .storageFailure,
                metadata: ["scope": "profile_refresh", "error": error.localizedDescription]
            )
        }
    }

    private func normalizedAvatarMimeType(preferredMimeType: String, originalData: Data) -> String {
        let normalized = preferredMimeType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "image/png" || normalized == "image/jpeg" || normalized == "image/jpg" || normalized == "image/webp" {
            return normalized == "image/jpg" ? "image/jpeg" : normalized
        }

        if originalData.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "image/png"
        }

        if originalData.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "image/jpeg"
        }

        return "image/jpeg"
    }

    private func resizedAvatarImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }
        let longestSide = max(sourceSize.width, sourceSize.height)
        guard longestSide > 0 else { return nil }

        let scale = min(1, maxDimension / longestSide)
        let targetSize = CGSize(
            width: max(1, floor(sourceSize.width * scale)),
            height: max(1, floor(sourceSize.height * scale))
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
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

        guard let legacyCallbackURL = URL(string: "sunnad://auth-callback"),
              let canonicalCallbackURL = URL(string: "adat://auth-callback")
        else {
            return false
        }

        let candidates = [dependencies.environment.authRedirectURL, canonicalCallbackURL, legacyCallbackURL]
        return candidates.contains(where: { Self.matchesCallbackRoute(url, candidate: $0) })
    }

    private static func matchesCallbackRoute(_ url: URL, candidate: URL) -> Bool {
        let normalizedPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedHost = (url.host ?? "").lowercased()
        let expectedPath = candidate.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let expectedHost = (candidate.host ?? "").lowercased()

        return (url.scheme ?? "").lowercased() == (candidate.scheme ?? "").lowercased()
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

    private static func isSignupCallbackURL(_ url: URL) -> Bool {
        let raw = url.absoluteString.lowercased()
        return raw.contains("type=signup") || raw.contains("type=magiclink")
    }

    private func resolvePromotionModeForAuthCallback(
        url: URL,
        shouldOpenRecoveryPassword: Bool
    ) -> GuestPromotionMode {
        guard !shouldOpenRecoveryPassword else {
            return .none
        }

        if Self.isSignupCallbackURL(url) {
            return .signup
        }

        if consumePendingOAuthIntent() == .signUp {
            return .signup
        }

        return .none
    }

    private func setPendingOAuthIntent(_ intent: OAuthIntent) {
        userDefaults.set(intent.rawValue, forKey: LocalStateKeys.pendingOAuthIntent)
    }

    private func consumePendingOAuthIntent() -> OAuthIntent? {
        guard let raw = userDefaults.string(forKey: LocalStateKeys.pendingOAuthIntent),
              let intent = OAuthIntent(rawValue: raw) else {
            return nil
        }

        userDefaults.removeObject(forKey: LocalStateKeys.pendingOAuthIntent)
        return intent
    }

    private func clearPendingOAuthIntent() {
        userDefaults.removeObject(forKey: LocalStateKeys.pendingOAuthIntent)
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
        replaceLocalHabitsTask?.cancel()
        replaceLocalHabitsTask = Task {
            cancelAllPersistTasks(cancelReplaceTask: false)
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

    private func settleLocalHabitPersistenceBeforePromotion() async {
        if let replaceLocalHabitsTask {
            await replaceLocalHabitsTask.value
            self.replaceLocalHabitsTask = nil
        }

        while !persistTasks.isEmpty {
            let pending = Array(persistTasks.values)
            if pending.isEmpty {
                break
            }
            for task in pending {
                await task.value
            }
        }
    }

    private func cancelAllPersistTasks() {
        cancelAllPersistTasks(cancelReplaceTask: true)
    }

    private func cancelAllPersistTasks(cancelReplaceTask: Bool) {
        for task in persistTasks.values {
            task.cancel()
        }
        persistTasks.removeAll()
        if cancelReplaceTask {
            replaceLocalHabitsTask?.cancel()
            replaceLocalHabitsTask = nil
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

    private func identifySignedInUser(_ sessionUser: SessionUser) {
        let distinctId = sessionUser.id.uuidString

        let firstSeenDate = analyticsFirstSeenDate(for: distinctId)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let firstSeenString = formatter.string(from: firstSeenDate)

        let userProperties: [String: Any] = [
            "is_guest": false,
            "language": language.rawValue,
            "locale": language.localeIdentifier,
            "is_test_account": resolvedIsTestAccount(),
        ]
        let setOnce: [String: Any] = [
            "first_seen_at": firstSeenString,
        ]

        dependencies.analytics.identify(
            distinctId,
            userProperties: userProperties,
            userPropertiesSetOnce: setOnce
        )

        updateAnalyticsPersonPropertiesIfNeeded()
    }

    private func updateAnalyticsPersonPropertiesIfNeeded() {
        guard let currentSessionUserID else { return }
        let distinctID = currentSessionUserID.uuidString
        let firstSeenDate = analyticsFirstSeenDate(for: distinctID)
        let calendar = Calendar.current
        let daysSinceSignup = max(0, calendar.dateComponents([.day], from: firstSeenDate, to: Date()).day ?? 0)
        let notificationsEnabled = notificationPreferences.habitReminders
            || notificationPreferences.quoteReminder
            || notificationPreferences.groupReminders
        let activeGroupCount = groupsViewModel.groups.filter { !$0.isPending }.count

        dependencies.analytics.setPersonProperties(
            [
                "habit_count": habits.count,
                "is_group_member": activeGroupCount > 0,
                "notifications_enabled": notificationsEnabled,
                "days_since_signup": daysSinceSignup,
                "is_test_account": resolvedIsTestAccount(),
            ],
            setOnce: nil
        )
    }

    private func analyticsFirstSeenDate(for distinctID: String) -> Date {
        let key = LocalStateKeys.analyticsFirstSeenDate(distinctID: distinctID)
        if let stored = userDefaults.object(forKey: key) as? Date {
            return stored
        }
        let now = Date()
        userDefaults.set(now, forKey: key)
        return now
    }

    private func resolvedIsTestAccount() -> Bool {
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["SUNNAD_ANALYTICS_TEST_ACCOUNT"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           !override.isEmpty {
            return override == "1" || override == "true" || override == "yes"
        }
        #endif

        return dependencies.environment == .development
    }

    private func trackStreakTransitions(using todayHabits: [UIHabit]) {
        let milestones = [3, 7, 14, 30, 60, 100]
        if streakByHabitID.isEmpty {
            streakByHabitID = Dictionary(uniqueKeysWithValues: todayHabits.map { ($0.id, max(0, $0.streak)) })
            return
        }
        var nextSnapshot: [UUID: Int] = [:]
        nextSnapshot.reserveCapacity(todayHabits.count)

        for habit in todayHabits {
            let previous = streakByHabitID[habit.id] ?? 0
            let current = max(0, habit.streak)
            let habitType = habit.isDhikr ? "dhikr" : "binary"

            if previous > 0, current == 0 {
                dependencies.analytics.trackStreak(
                    .broken(
                        habitType: habitType,
                        previousStreakLength: previous
                    )
                )
            }

            if current > previous {
                for milestone in milestones where previous < milestone && current >= milestone {
                    dependencies.analytics.trackStreak(
                        .achieved(
                            habitType: habitType,
                            streakLength: current,
                            milestone: milestone
                        )
                    )
                }
            }

            nextSnapshot[habit.id] = current
        }

        streakByHabitID = nextSnapshot
    }

    private func startConnectivityMonitoring() {
        connectivityMonitor.pathUpdateHandler = { [weak self] path in
            let isOnline = path.status == .satisfied
            DispatchQueue.main.async {
                self?.sessionTracker.updateConnectivity(isOnline: isOnline)
            }
        }
        connectivityMonitor.start(queue: connectivityMonitorQueue)
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
                otpFlowMode = .signup
                activateOTPCooldown(flow: .signup, email: pendingSignUpEmail)
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
                openQuoteOfDay()
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
        UIUserState(isGuest: false, name: displayName, email: email, avatarURL: avatarURL)
    }
}

actor OneSignalBridge {
    static let shared = OneSignalBridge()

    private enum Keys {
        static let subscriptionID = "sunnad.device.onesignal-subscription-id"
        static let sharedSubscriptionID = "sunnad.onesignal.subscription-id"
        static let sharedAppID = "sunnad.onesignal.app-id"
    }

    private let userDefaults = UserDefaults.standard
    private var configuredAppID: String?
    private var configuredAppGroupID: String?

    func configure(appID: String?, appGroupID: String? = nil) {
        let trimmed = appID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedGroupID = appGroupID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedGroupID.isEmpty {
            configuredAppGroupID = trimmedGroupID
        }
        guard !trimmed.isEmpty else { return }
        guard configuredAppID != trimmed else { return }

        #if canImport(OneSignalFramework)
        OneSignal.initialize(trimmed, withLaunchOptions: nil)
        #endif
        configuredAppID = trimmed
        sharedDefaults?.set(trimmed, forKey: Keys.sharedAppID)
    }

    func login(externalID: String) async {
        guard !externalID.isEmpty else { return }
        guard configuredAppID != nil else { return }

        #if canImport(OneSignalFramework)
        OneSignal.login(externalID)
        #endif
        await refreshSubscriptionID()
    }

    func logout() {
        #if canImport(OneSignalFramework)
        OneSignal.logout()
        #endif
        userDefaults.removeObject(forKey: Keys.subscriptionID)
        sharedDefaults?.removeObject(forKey: Keys.sharedSubscriptionID)
    }

    private func refreshSubscriptionID() async {
        for _ in 0 ..< 8 {
            if let id = currentSubscriptionID() {
                userDefaults.set(id, forKey: Keys.subscriptionID)
                sharedDefaults?.set(id, forKey: Keys.sharedSubscriptionID)
                return
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    private var sharedDefaults: UserDefaults? {
        guard let groupID = configuredAppGroupID, !groupID.isEmpty else { return nil }
        return UserDefaults(suiteName: groupID)
    }

    private func currentSubscriptionID() -> String? {
        #if canImport(OneSignalFramework)
        let raw = OneSignal.User.pushSubscription.id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? nil : raw
        #else
        return nil
        #endif
    }
}
