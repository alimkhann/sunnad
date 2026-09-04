import SwiftUI

struct SunnadRootView: View {
    @Environment(\.scenePhase) private var scenePhase
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
                    otpFlowMode: state.otpFlowMode,
                    otpResendSecondsRemaining: state.otpResendSecondsRemaining,
                    authErrorMessage: state.authErrorMessage,
                    authSuccessMessage: state.authSuccessMessage,
                    googleAuthEnabled: state.isGoogleAuthEnabled,
                    appleAuthEnabled: state.isAppleAuthEnabled,
                    onOpenLanguagePicker: { state.rootSheet = .languagePicker },
                    onCompleteTemplateSelection: { state.completeTemplateSelection() },
                    onEnableNotifications: state.enableOnboardingNotifications,
                    onSkipNotifications: state.skipOnboardingNotifications,
                    onJoinGroupsAppeared: state.promptNotificationsOnJoinGroupsIfNeeded,
                    onCompleteAsGuest: state.completeAsGuest,
                    onOpenSignIn: state.openSignIn,
                    onOpenSignUp: state.openSignUp,
                    onSignIn: state.handleSignIn,
                    onSignUp: state.handleSignUp,
                    onGoogleSignIn: state.handleGoogleSignIn,
                    onGoogleSignUp: state.handleGoogleSignUp,
                    onAppleSignIn: state.handleAppleSignIn,
                    onAppleSignUp: state.handleAppleSignUp,
                    onOTPVerify: state.verifyOTP,
                    onResendOTP: state.resendOTP,
                    onOpenForgotPassword: state.openOnboardingForgotPassword,
                    onClearAuthError: state.clearAuthError
                )
            } else {
                mainTabs
            }
        }
        .onAppear {
            trackCurrentScreen()
            state.appDidBecomeActive()
        }
        .onChange(of: state.activeTab) { _, _ in
            guard !state.showsOnboarding else { return }
            trackCurrentScreen()
        }
        .onChange(of: state.showsOnboarding) { _, _ in
            trackCurrentScreen()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                state.appDidBecomeActive()
            } else if phase == .background {
                state.appDidEnterBackground()
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
                    lateCheckInCandidates: state.lateCheckInCandidates,
                    quote: state.todayQuote,
                    isLoading: state.isInitialLoad,
                    onToggle: { state.toggleTodayHabit($0) },
                    onSelectHabit: { state.rootSheet = .habitDetail($0.id) },
                    onManage: { state.fullScreen = .schedule },
                    onAddHabit: { state.rootSheet = .addHabit },
                    onLateCheckIn: state.recordLateCheckIn,
                    onOpenQuote: state.openQuoteOfDay
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
                    isLoading: state.groupsViewModel.isLoading || state.isInitialLoad,
                    errorMessage: state.groupsViewModel.errorMessage,
                    onRefresh: state.refreshGroups,
                    onCreateGroup: { state.rootSheet = .createGroup },
                    onJoinGroup: { state.rootSheet = .joinGroup },
                    onSignIn: state.signInFromGroups,
                    onOpenGroup: state.trackGroupOpened,
                    onUpdateGroupSharing: state.updateGroupSharing,
                    onToggleOwnHabit: state.toggleHabit,
                    onSendReminder: state.sendGroupNudge,
                    onLeaveGroup: state.leaveGroup,
                    onDeleteGroup: state.deleteGroup,
                    onKickMember: state.kickMember,
                    onSetProgressDisplayMode: state.setGroupProgressDisplayMode,
                    onRenameGroup: state.renameGroup,
                    onSetJoinLock: state.setGroupJoinLock,
                    onRotateInviteCode: state.rotateGroupInviteCode,
                    onRefreshGroup: state.refreshGroup,
                    onGroupMemberProgressViewed: state.trackGroupMemberProgressViewed,
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
                    feedbackPreferences: $state.feedbackPreferences,
                    onManageHabits: {
                        state.activeTab = .today
                        state.fullScreen = .schedule
                    },
                    onOpenSavedQuotes: { state.rootSheet = .savedQuotes },
                    onOpenLanguagePicker: { state.rootSheet = .languagePicker },
                    onOpenInsights: {
                        state.trackScreen(.insights)
                        state.fullScreen = .insightsPlaceholder
                    },
                    onSignIn: state.openProfileSignIn,
                    onSignOut: state.signOut,
                    onEditProfile: state.openProfileEditor,
                    onChangePassword: state.openChangePassword,
                    onDeleteData: state.deleteData,
                    onDeleteAccount: state.deleteAccount,
                    onRefresh: state.refreshProfile,
                    debugDiagnosticsText: state.profileDebugDiagnosticsText,
                    termsURL: state.termsURL,
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
                onAddCustomHabit: { name, icon, category, categoryCustom, schedule, weekdays, reminderTime, hasDhikrCounter in
                    state.addCustomHabit(
                        name: name,
                        iconSystemName: icon,
                        category: category,
                        categoryCustom: categoryCustom,
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
                    onUpdateHabitSharing: state.updateHabitSharing,
                    onDhikrIncremented: state.handleDhikrCounterIncrement
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
                },
                onShare: { channel in
                    state.trackQuoteShared(channel: channel)
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

    private func trackCurrentScreen() {
        if state.showsOnboarding {
            state.trackScreen(.onboarding)
            return
        }

        switch state.activeTab {
        case .today:
            state.trackScreen(.today)
        case .groups:
            state.trackScreen(.groups)
        case .profile:
            state.trackScreen(.profile)
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
                onGoogle: state.handleGoogleProfileSignIn,
                onApple: state.handleAppleProfileSignIn,
                isGoogleEnabled: state.isGoogleAuthEnabled,
                isAppleEnabled: state.isAppleAuthEnabled,
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
                onGoogle: state.handleGoogleProfileSignUp,
                onApple: state.handleAppleProfileSignUp,
                isGoogleEnabled: state.isGoogleAuthEnabled,
                isAppleEnabled: state.isAppleAuthEnabled,
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
        case .editProfile:
            EditProfileView(
                user: state.user,
                authErrorMessage: state.authErrorMessage,
                authSuccessMessage: state.authSuccessMessage,
                onBack: { state.fullScreen = nil },
                onSaveUsername: state.submitProfileUsername,
                onUploadAvatar: state.uploadProfileAvatar,
                onRemoveAvatar: state.removeProfileAvatar,
                onClearMessage: state.clearAuthError
            )
        case .profileOTP:
            OTPVerificationView(
                email: state.pendingSignUpEmail,
                flowMode: state.otpFlowMode,
                resendSecondsRemaining: state.otpResendSecondsRemaining,
                onBack: state.openProfileSignUp,
                onVerify: state.verifyProfileOTP,
                onResend: state.resendProfileOTP,
                authErrorMessage: state.authErrorMessage,
                onClearMessage: state.clearAuthError,
                showsBackButton: false,
                onClose: { state.fullScreen = nil }
            )
        case .forgotPasswordOTPOnboarding:
            OTPVerificationView(
                email: state.pendingPasswordResetEmail,
                flowMode: .recovery,
                resendSecondsRemaining: state.otpResendSecondsRemaining,
                onBack: state.closeOnboardingForgotPasswordOTP,
                onVerify: state.verifyOTP,
                onResend: state.resendOTP,
                authErrorMessage: state.authErrorMessage,
                onClearMessage: state.clearAuthError
            )
        case .forgotPasswordOTPProfile:
            OTPVerificationView(
                email: state.pendingPasswordResetEmail,
                flowMode: .recovery,
                resendSecondsRemaining: state.otpResendSecondsRemaining,
                onBack: state.closeProfileForgotPasswordOTP,
                onVerify: state.verifyProfileOTP,
                onResend: state.resendProfileOTP,
                authErrorMessage: state.authErrorMessage,
                onClearMessage: state.clearAuthError,
                showsBackButton: false,
                onClose: { state.fullScreen = nil }
            )
        }
    }
}
