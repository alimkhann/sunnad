import SwiftUI

struct SunnadRootView: View {
    @StateObject private var state: AppRouteState

    init(dependencies: DependencyContainer) {
        _state = StateObject(wrappedValue: AppRouteState(dependencies: dependencies))
    }

    var body: some View {
        SwiftUI.Group {
            if state.showsOnboarding {
                OnboardingFlowView(
                    step: $state.onboardingStep,
                    selectedTemplateIDs: $state.selectedTemplateIDs,
                    pendingEmail: state.pendingSignUpEmail,
                    authErrorMessage: state.authErrorMessage,
                    authSuccessMessage: state.authSuccessMessage,
                    onOpenLanguagePicker: { state.rootSheet = .languagePicker },
                    onCompleteTemplateSelection: { state.completeTemplateSelection() },
                    onEnableNotifications: state.enableOnboardingNotifications,
                    onSkipNotifications: state.skipOnboardingNotifications,
                    onCompleteAsGuest: state.completeAsGuest,
                    onOpenSignIn: state.openSignIn,
                    onOpenSignUp: state.openSignUp,
                    onSignIn: state.handleSignIn,
                    onSignUp: state.handleSignUp,
                    onOTPVerify: state.verifyOTP,
                    onOpenForgotPassword: state.openOnboardingForgotPassword,
                    onClearAuthError: state.clearAuthError
                )
            } else {
                mainTabs
            }
        }
        .environment(\.locale, Locale(identifier: state.language.localeIdentifier))
        .preferredColorScheme(state.appearance.colorScheme)
        .sheet(item: $state.rootSheet, content: sheetView)
        .fullScreenCover(item: $state.fullScreen, content: fullScreenView)
        .onOpenURL(perform: state.handleIncomingURL)
    }

    private var mainTabs: some View {
        TabView(selection: $state.activeTab) {
            NavigationStack {
                TodayView(
                    habits: state.todayHabits,
                    quote: state.todayQuote,
                    onToggle: state.toggleTodayHabit,
                    onSelectHabit: { state.rootSheet = .habitDetail($0.id) },
                    onManage: { state.fullScreen = .schedule },
                    onAddHabit: { state.rootSheet = .addHabit },
                    onOpenQuote: { state.rootSheet = .quoteOfDay }
                )
            }
            .sunnadSolidBars()
            .tabItem {
                Label(L10n.t("tab.today"), systemImage: "calendar")
            }
            .tag(AppTab.today)

            NavigationStack {
                GroupsView(
                    groups: state.groupsViewModel.groups,
                    user: state.groupsViewModel.user,
                    habits: state.groupsViewModel.habits,
                    onCreateGroup: { state.rootSheet = .createGroup },
                    onJoinGroup: { state.rootSheet = .joinGroup },
                    onSignIn: state.signInFromGroups,
                    onUpdateGroupSharing: state.updateGroupSharing,
                    onToggleOwnHabit: state.toggleHabit,
                    onLeaveGroup: state.leaveGroup,
                    onDeleteGroup: state.deleteGroup,
                    onKickMember: state.kickMember,
                    currentGroupSharedHabitIDs: { groupID in
                        state.groupsViewModel.currentGroupSharedHabitIDs(for: groupID)
                    }
                )
            }
            .sunnadSolidBars()
            .tabItem {
                Label(L10n.t("tab.groups"), systemImage: "person.2")
            }
            .tag(AppTab.groups)

            NavigationStack {
                ProfileView(
                    user: state.profileViewModel.user,
                    habits: state.profileViewModel.habits,
                    savedQuotes: state.profileViewModel.savedQuotes,
                    selectedLanguage: state.language,
                    selectedAppearance: $state.appearance,
                    notificationPreferences: $state.notificationPreferences,
                    onManageHabits: {
                        state.activeTab = .today
                        state.fullScreen = .schedule
                    },
                    onOpenSavedQuotes: { state.rootSheet = .savedQuotes },
                    onOpenLanguagePicker: { state.rootSheet = .languagePicker },
                    onOpenInsights: { state.fullScreen = .insightsPlaceholder },
                    onSignIn: state.openProfileSignIn,
                    onSignOut: state.signOut,
                    onChangePassword: state.openChangePassword,
                    onDeleteData: state.deleteData,
                    onDeleteAccount: state.deleteAccount,
                    privacyURL: state.privacyURL,
                    helpURL: state.helpURL
                )
            }
            .sunnadSolidBars()
            .tabItem {
                Label(L10n.t("tab.profile"), systemImage: "person.crop.circle")
            }
            .tag(AppTab.profile)
        }
        .overlay(alignment: .topLeading) {
            if state.isUITestMode {
                Text("\(state.debugPendingReminderCount)")
                    .font(.caption2)
                    .foregroundStyle(.clear)
                    .accessibilityIdentifier("debug.reminder.pending.count")
            }
        }
        .sunnadSolidBars()
    }

    @ViewBuilder
    private func sheetView(route: RootSheetRoute) -> some View {
        switch route {
        case .addHabit:
            AddHabitSheetView(
                existingHabits: state.habits,
                onAddTemplates: { templates in
                    state.addTemplateHabits(templates)
                },
                onAddCustomHabit: { name, icon, category, schedule, weekdays, reminderTime, hasDhikrCounter in
                    state.addCustomHabit(
                        name: name,
                        iconSystemName: icon,
                        category: category,
                        schedule: schedule,
                        weekdays: weekdays,
                        reminderTime: reminderTime,
                        hasDhikrCounter: hasDhikrCounter
                    )
                }
            )
        case .habitDetail(let habitID):
            if let binding = state.bindingForHabit(habitID: habitID) {
                HabitDetailSheetView(
                    habit: binding,
                    user: state.user,
                    groups: state.groupsViewModel.groups,
                    lastSevenCompletionMarksOverride: state.lastSevenCompletionMarks(for: habitID),
                    onDelete: state.deleteHabit,
                    onUpdateHabitSharing: state.updateHabitSharing
                )
            } else {
                PlaceholderScreen(
                    title: L10n.t("placeholder.not_found.title"),
                    message: L10n.t("placeholder.not_found.subtitle")
                )
            }
        case .quoteOfDay:
            QuoteOfDaySheetView(
                quote: state.todayQuote,
                shareLink: state.publicAppLink,
                onSave: {
                    state.saveCurrentQuote()
                }
            )
        case .createGroup:
            CreateGroupSheet(onCreate: state.createGroup)
        case .joinGroup:
            JoinGroupSheet(onJoin: state.joinGroup)
        case .savedQuotes:
            SavedQuotesView(quotes: state.profileViewModel.savedQuotes)
        case .languagePicker:
            LanguagePickerSheet(selected: state.language) {
                state.language = $0
            }
        case .reminderPlaceholder:
            PlaceholderScreen(
                title: L10n.t("groups.reminder.placeholder.title"),
                message: L10n.t("groups.reminder.placeholder.subtitle")
            )
        }
    }

    @ViewBuilder
    private func fullScreenView(route: FullScreenRoute) -> some View {
        switch route {
        case .schedule:
            ScheduleScreenView(
                habits: $state.habits,
                onSelectHabit: { habit in
                    state.rootSheet = .habitDetail(habit.id)
                },
                onReorderHabits: state.reorderHabits
            )
        case .insightsPlaceholder:
            InsightsView(viewModel: state.insightsViewModel)
        case .weekPlaceholder:
            PlaceholderScreen(
                title: L10n.t("schedule.week.placeholder.title"),
                message: L10n.t("schedule.week.placeholder.subtitle")
            )
        case .monthPlaceholder:
            PlaceholderScreen(
                title: L10n.t("schedule.month.placeholder.title"),
                message: L10n.t("schedule.month.placeholder.subtitle")
            )
        case .profileSignIn:
            SignInView(
                onBack: {},
                onSwitchToSignUp: state.openProfileSignUp,
                onSubmit: state.handleProfileSignIn,
                authErrorMessage: state.authErrorMessage,
                authSuccessMessage: state.authSuccessMessage,
                onClearError: state.clearAuthError,
                onForgotPassword: state.openProfileForgotPassword,
                showsBackButton: false,
                onClose: { state.fullScreen = nil }
            )
        case .profileSignUp:
            SignUpView(
                onBack: state.openProfileSignIn,
                onSwitchToSignIn: state.openProfileSignIn,
                onSubmit: state.handleProfileSignUp,
                authErrorMessage: state.authErrorMessage,
                onClearError: state.clearAuthError,
                showsBackButton: false,
                onClose: { state.fullScreen = nil }
            )
        case .forgotPasswordOnboarding:
            ForgotPasswordView(
                initialEmail: state.pendingPasswordResetEmail,
                onBack: state.closeOnboardingForgotPassword,
                onSubmit: state.submitPasswordResetRequest,
                authErrorMessage: state.authErrorMessage,
                authSuccessMessage: state.authSuccessMessage,
                onClearMessage: state.clearAuthError
            )
        case .forgotPasswordProfile:
            ForgotPasswordView(
                initialEmail: state.pendingPasswordResetEmail,
                onBack: state.closeProfileForgotPassword,
                onSubmit: state.submitPasswordResetRequest,
                authErrorMessage: state.authErrorMessage,
                authSuccessMessage: state.authSuccessMessage,
                onClearMessage: state.clearAuthError
            )
        case .changePassword:
            ChangePasswordView(
                onBack: { state.fullScreen = nil },
                onSubmit: state.submitChangePassword,
                authErrorMessage: state.authErrorMessage,
                onClearMessage: state.clearAuthError
            )
        case .profileOTP:
            OTPVerificationView(
                email: state.pendingSignUpEmail,
                onBack: state.openProfileSignUp,
                onVerify: state.verifyProfileOTP,
                showsBackButton: false,
                onClose: { state.fullScreen = nil }
            )
        }
    }
}
