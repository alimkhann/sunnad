import SwiftUI

struct SunnadRootView: View {
    @StateObject private var state = AppRouteState()

    var body: some View {
        Group {
            if state.showsOnboarding {
                OnboardingFlowView(
                    step: $state.onboardingStep,
                    selectedTemplateIDs: $state.selectedTemplateIDs,
                    pendingEmail: state.pendingSignUpEmail,
                    onOpenLanguagePicker: { state.rootSheet = .languagePicker },
                    onCompleteTemplateSelection: { state.completeTemplateSelection() },
                    onFinishNotifications: { state.onboardingStep = .joinGroups },
                    onCompleteAsGuest: state.completeAsGuest,
                    onOpenSignIn: state.openSignIn,
                    onOpenSignUp: state.openSignUp,
                    onSignIn: state.handleSignIn,
                    onSignUp: state.handleSignUp,
                    onOTPVerify: state.verifyOTP
                )
            } else {
                mainTabs
            }
        }
        .environment(\.locale, Locale(identifier: state.language.localeIdentifier))
        .sheet(item: $state.rootSheet, content: sheetView)
        .fullScreenCover(item: $state.fullScreen, content: fullScreenView)
    }

    private var mainTabs: some View {
        TabView(selection: $state.activeTab) {
            NavigationStack {
                TodayView(
                    habits: state.todayHabits,
                    quote: UIFixtures.dailyQuote,
                    onToggle: state.toggleHabit,
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
                    groups: state.groups,
                    user: state.user,
                    habits: state.habits,
                    onCreateGroup: { state.rootSheet = .createGroup },
                    onJoinGroup: { state.rootSheet = .joinGroup },
                    onSignIn: state.signInFromGroups,
                    onUpdateGroupSharing: state.updateGroupSharing,
                    onOpenReminderPlaceholder: { state.rootSheet = .reminderPlaceholder }
                )
            }
            .sunnadSolidBars()
            .tabItem {
                Label(L10n.t("tab.groups"), systemImage: "person.2")
            }
            .tag(AppTab.groups)

            NavigationStack {
                ProfileView(
                    user: state.user,
                    habits: state.habits,
                    savedQuotes: state.savedQuotes,
                    selectedLanguage: state.language,
                    onManageHabits: {
                        state.activeTab = .today
                        state.fullScreen = .schedule
                    },
                    onOpenSavedQuotes: { state.rootSheet = .savedQuotes },
                    onOpenLanguagePicker: { state.rootSheet = .languagePicker },
                    onOpenInsights: { state.fullScreen = .insightsPlaceholder },
                    onSignIn: state.signInFromGroups,
                    onSignOut: state.signOut
                )
            }
            .sunnadSolidBars()
            .tabItem {
                Label(L10n.t("tab.profile"), systemImage: "person.crop.circle")
            }
            .tag(AppTab.profile)
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
                    groups: state.groups,
                    onDelete: state.deleteHabit
                )
            } else {
                PlaceholderScreen(
                    title: L10n.t("placeholder.not_found.title"),
                    message: L10n.t("placeholder.not_found.subtitle")
                )
            }
        case .quoteOfDay:
            QuoteOfDaySheetView(
                quote: UIFixtures.dailyQuote,
                onSave: {
                    state.saveQuote(UIFixtures.dailyQuote)
                }
            )
        case .createGroup:
            CreateGroupSheet(onCreate: state.createGroup)
        case .joinGroup:
            JoinGroupSheet(onJoin: state.joinGroup)
        case .savedQuotes:
            SavedQuotesView(quotes: state.savedQuotes)
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
                }
            )
        case .insightsPlaceholder:
            PlaceholderScreen(
                title: L10n.t("insights.placeholder.title"),
                message: L10n.t("insights.placeholder.subtitle")
            )
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
        }
    }
}
