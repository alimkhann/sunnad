package com.arystan.almasuly.sunnadandroid.app

import android.net.Uri
import androidx.appcompat.app.AppCompatDelegate
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.adaptive.navigationsuite.NavigationSuiteScaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.core.os.LocaleListCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.arystan.almasuly.sunnadandroid.BuildConfig
import com.arystan.almasuly.sunnadandroid.R
import com.arystan.almasuly.sunnadandroid.SunnadApplication
import com.arystan.almasuly.sunnadandroid.features.auth.AuthFlowScreen
import com.arystan.almasuly.sunnadandroid.features.auth.AuthStep
import com.arystan.almasuly.sunnadandroid.features.auth.AuthViewModel
import com.arystan.almasuly.sunnadandroid.features.groups.GroupsScreen
import com.arystan.almasuly.sunnadandroid.features.groups.GroupsViewModel
import com.arystan.almasuly.sunnadandroid.features.insights.InsightsScreen
import com.arystan.almasuly.sunnadandroid.features.onboarding.OnboardingFlowScreen
import com.arystan.almasuly.sunnadandroid.features.profile.ProfileScreen
import com.arystan.almasuly.sunnadandroid.features.profile.ProfileViewModel
import com.arystan.almasuly.sunnadandroid.features.today.TodayScreen
import com.arystan.almasuly.sunnadandroid.features.today.TodayViewModel
import com.arystan.almasuly.sunnadandroid.services.AppAppearance
import com.arystan.almasuly.sunnadandroid.services.AppLanguage
import com.arystan.almasuly.sunnadandroid.sync.SyncTrigger
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenPadding
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenSurface
import com.arystan.almasuly.sunnadandroid.ui.theme.SunnadTheme
import java.time.LocalDate
import java.util.UUID

@Composable
fun SunnadApp(
    pendingAuthCallback: Uri? = null,
    onAuthCallbackConsumed: () -> Unit = {}
) {
    val app = LocalContext.current.applicationContext as SunnadApplication
    val container = app.container

    val authViewModel: AuthViewModel = viewModel(
        factory = SunnadViewModelFactory { AuthViewModel(container.authService) }
    )
    val profileViewModel: ProfileViewModel = viewModel(
        factory = SunnadViewModelFactory {
            ProfileViewModel(
                quotesRepository = container.quotesRepository,
                settingsStore = container.settingsStore,
                syncCoordinator = container.syncCoordinator
            )
        }
    )
    val todayViewModel: TodayViewModel = viewModel(
        factory = SunnadViewModelFactory {
            TodayViewModel(
                habitsRepository = container.habitsRepository,
                completionsRepository = container.completionsRepository,
                quotesRepository = container.quotesRepository,
                syncCoordinator = container.syncCoordinator
            )
        }
    )
    val groupsViewModel: GroupsViewModel = viewModel(
        factory = SunnadViewModelFactory {
            GroupsViewModel(container.groupsRepository, container.syncCoordinator)
        }
    )

    val profileState by profileViewModel.state.collectAsStateWithLifecycle()
    val todayState by todayViewModel.state.collectAsStateWithLifecycle()
    val groupsState by groupsViewModel.state.collectAsStateWithLifecycle()
    val authState by authViewModel.state.collectAsStateWithLifecycle()

    val onboardingCompleted = profileState.settings.onboardingCompleted

    var rootGraph by rememberSaveable { mutableStateOf(RootGraph.LOADING) }
    var onboardingRoute by rememberSaveable { mutableStateOf(OnboardingRoute.WELCOME) }
    var authRoute by rememberSaveable { mutableStateOf(AuthRoute.SIGN_IN) }
    var selectedTab by rememberSaveable { mutableStateOf(MainTabRoute.TODAY) }
    var profileOverlay by rememberSaveable { mutableStateOf(ProfileOverlay.NONE) }
    var promotedUserId by rememberSaveable { mutableStateOf<String?>(null) }
    var pushTokenUserId by rememberSaveable { mutableStateOf<String?>(null) }

    val darkThemeMode = when (profileState.appearance) {
        AppAppearance.SYSTEM -> null
        AppAppearance.LIGHT -> false
        AppAppearance.DARK -> true
    }

    LaunchedEffect(Unit) {
        authViewModel.restoreSession()
    }

    LaunchedEffect(pendingAuthCallback) {
        pendingAuthCallback?.let {
            authViewModel.handleAuthCallback(it)
            onAuthCallbackConsumed()
        }
    }

    LaunchedEffect(profileState.settings.language) {
        todayViewModel.updateLocale(profileState.settings.language)
        AppCompatDelegate.setApplicationLocales(
            LocaleListCompat.forLanguageTags(profileState.settings.language)
        )
    }

    LaunchedEffect(
        profileState.settings.habitRemindersEnabled,
        profileState.settings.quoteReminderEnabled,
        profileState.settings.language,
        todayState.allHabits,
        todayState.dueHabits
    ) {
        val completedTodayIds = todayState.dueHabits
            .filter { it.completedToday }
            .map { it.id }
            .toSet()
        container.reminderScheduler.syncHabitReminders(
            habits = todayState.allHabits,
            enabled = profileState.settings.habitRemindersEnabled,
            completedHabitIds = completedTodayIds
        )
        container.reminderScheduler.syncQuoteReminders(
            enabled = profileState.settings.quoteReminderEnabled,
            locale = profileState.settings.language,
            startDay = LocalDate.now()
        )
    }

    LaunchedEffect(authState.user?.id) {
        val debugPushToken = BuildConfig.SUNNAD_DEBUG_PUSH_TOKEN.trim()
        if (debugPushToken.isBlank()) return@LaunchedEffect
        val signedInUser = authState.user
        if (signedInUser != null) {
            container.pushTokenSyncService.registerToken(signedInUser.id, debugPushToken)
            pushTokenUserId = signedInUser.id.toString()
        } else {
            val previousId = pushTokenUserId ?: return@LaunchedEffect
            val previousUuid = runCatching { UUID.fromString(previousId) }.getOrNull()
            if (previousUuid != null) {
                container.pushTokenSyncService.clearToken(previousUuid, debugPushToken)
            }
            pushTokenUserId = null
        }
    }

    LaunchedEffect(onboardingCompleted, authState.user, rootGraph, onboardingRoute) {
        container.ownerScopeResolver.setSignedInUserId(authState.user?.id)
        container.syncCoordinator.setSignedInUserId(authState.user?.id)
        val userId = authState.user?.id
        if (userId != null && promotedUserId != userId.toString()) {
            container.syncCoordinator.promoteGuestDataIfNeeded(userId)
            container.syncCoordinator.runSyncCycle(SyncTrigger.AUTH)
            promotedUserId = userId.toString()
        }

        when {
            rootGraph == RootGraph.LOADING -> {
                val startup = resolveStartupRoute(
                    hasCompletedOnboarding = onboardingCompleted,
                    hasAuthenticatedSession = authState.user != null,
                    hasPendingAuthCallback = pendingAuthCallback != null,
                    hasConfiguredAuth = authState.isConfigured
                )
                rootGraph = startup.rootGraph
                startup.onboardingRoute?.let { onboardingRoute = it }
                startup.authRoute?.let { authRoute = it }
            }

            !onboardingCompleted -> {
                rootGraph = RootGraph.ONBOARDING
            }

            rootGraph == RootGraph.AUTH && authState.user != null -> {
                rootGraph = RootGraph.MAIN
                selectedTab = MainTabRoute.TODAY
            }

            rootGraph == RootGraph.AUTH && !authState.isConfigured -> {
                rootGraph = RootGraph.MAIN
                selectedTab = MainTabRoute.TODAY
            }

            rootGraph == RootGraph.ONBOARDING && authState.user != null -> {
                profileViewModel.setOnboardingCompleted(true)
                rootGraph = RootGraph.MAIN
                selectedTab = MainTabRoute.TODAY
            }
        }
    }

    SunnadTheme(forcedDarkTheme = darkThemeMode) {
        when (rootGraph) {
            RootGraph.LOADING -> {
                SunnadScreenSurface {
                    Row(
                        modifier = androidx.compose.ui.Modifier
                            .fillMaxWidth()
                            .padding(SunnadScreenPadding),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(stringResource(R.string.common_loading), style = MaterialTheme.typography.bodyLarge)
                    }
                }
            }

            RootGraph.ONBOARDING -> {
                when (onboardingRoute) {
                    OnboardingRoute.WELCOME,
                    OnboardingRoute.TEMPLATES,
                    OnboardingRoute.NOTIFICATIONS,
                    OnboardingRoute.JOIN_GROUPS -> {
                        OnboardingFlowScreen(
                            route = onboardingRoute,
                            onRouteChange = { onboardingRoute = it },
                            onCompleteAsGuest = { selectedTemplates ->
                                if (selectedTemplates.isNotEmpty()) {
                                    todayViewModel.seedHabitsFromTemplates(selectedTemplates)
                                }
                                profileViewModel.setOnboardingCompleted(true)
                                rootGraph = RootGraph.MAIN
                                selectedTab = MainTabRoute.TODAY
                            },
                            onOpenSignIn = {
                                onboardingRoute = OnboardingRoute.SIGN_IN
                                authViewModel.openStep(AuthStep.SIGN_IN)
                            },
                            onOpenSignUp = {
                                onboardingRoute = OnboardingRoute.SIGN_UP
                                authViewModel.openStep(AuthStep.SIGN_UP)
                            },
                            onSetLanguage = profileViewModel::setLanguage,
                            onEnableNotifications = {},
                            onSkipNotifications = {},
                            selectedLanguage = profileState.language
                        )
                    }

                    OnboardingRoute.SIGN_IN,
                    OnboardingRoute.SIGN_UP,
                    OnboardingRoute.OTP -> {
                        val targetStep = when (onboardingRoute) {
                            OnboardingRoute.SIGN_IN -> AuthStep.SIGN_IN
                            OnboardingRoute.SIGN_UP -> AuthStep.SIGN_UP
                            OnboardingRoute.OTP -> AuthStep.OTP
                            else -> AuthStep.SIGN_IN
                        }
                        LaunchedEffect(targetStep) {
                            authViewModel.openStep(targetStep)
                        }

                        AuthFlowScreen(
                            state = authState,
                            onBack = {
                                onboardingRoute = when (authState.step) {
                                    AuthStep.SIGN_IN,
                                    AuthStep.SIGN_UP -> OnboardingRoute.JOIN_GROUPS
                                    AuthStep.OTP -> OnboardingRoute.SIGN_UP
                                    AuthStep.FORGOT_PASSWORD -> OnboardingRoute.SIGN_IN
                                }
                            },
                            onClose = null,
                            onOpenStep = {
                                onboardingRoute = when (it) {
                                    AuthStep.SIGN_IN -> OnboardingRoute.SIGN_IN
                                    AuthStep.SIGN_UP -> OnboardingRoute.SIGN_UP
                                    AuthStep.OTP -> OnboardingRoute.OTP
                                    AuthStep.FORGOT_PASSWORD -> OnboardingRoute.SIGN_IN
                                }
                                authViewModel.openStep(it)
                            },
                            onSignIn = authViewModel::signIn,
                            onSignUp = authViewModel::signUp,
                            onRequestPasswordReset = authViewModel::requestPasswordReset,
                            onVerifyOtp = authViewModel::verifyOtp,
                            onResendOtp = authViewModel::resendOtp,
                            onGoogleSignIn = authViewModel::signInWithGoogle,
                            onAppleSignIn = authViewModel::signInWithApplePrewired,
                            onContinueAsGuest = {
                                onboardingRoute = OnboardingRoute.JOIN_GROUPS
                            }
                        )
                    }
                }
            }

            RootGraph.AUTH -> {
                val forcedStep = when (authRoute) {
                    AuthRoute.SIGN_IN -> AuthStep.SIGN_IN
                    AuthRoute.SIGN_UP -> AuthStep.SIGN_UP
                    AuthRoute.OTP -> AuthStep.OTP
                    AuthRoute.FORGOT_PASSWORD -> AuthStep.FORGOT_PASSWORD
                }
                LaunchedEffect(forcedStep) {
                    authViewModel.openStep(forcedStep)
                }
                AuthFlowScreen(
                    state = authState,
                    onBack = if (authState.step == AuthStep.OTP || authState.step == AuthStep.FORGOT_PASSWORD) {
                        { authViewModel.openStep(AuthStep.SIGN_IN) }
                    } else {
                        null
                    },
                    onClose = { rootGraph = RootGraph.MAIN },
                    onOpenStep = { step ->
                        authRoute = when (step) {
                            AuthStep.SIGN_IN -> AuthRoute.SIGN_IN
                            AuthStep.SIGN_UP -> AuthRoute.SIGN_UP
                            AuthStep.OTP -> AuthRoute.OTP
                            AuthStep.FORGOT_PASSWORD -> AuthRoute.FORGOT_PASSWORD
                        }
                        authViewModel.openStep(step)
                    },
                    onSignIn = authViewModel::signIn,
                    onSignUp = authViewModel::signUp,
                    onRequestPasswordReset = authViewModel::requestPasswordReset,
                    onVerifyOtp = authViewModel::verifyOtp,
                    onResendOtp = authViewModel::resendOtp,
                    onGoogleSignIn = authViewModel::signInWithGoogle,
                    onAppleSignIn = authViewModel::signInWithApplePrewired,
                    onContinueAsGuest = { rootGraph = RootGraph.MAIN }
                )
            }

            RootGraph.MAIN -> {
                NavigationSuiteScaffold(
                    navigationSuiteItems = {
                        item(
                            icon = { Icon(Icons.Rounded.CalendarMonth, contentDescription = stringResource(R.string.tab_today)) },
                            label = { Text(stringResource(R.string.tab_today)) },
                            selected = selectedTab == MainTabRoute.TODAY,
                            onClick = { selectedTab = MainTabRoute.TODAY }
                        )
                        item(
                            icon = { Icon(Icons.Rounded.Groups, contentDescription = stringResource(R.string.tab_groups)) },
                            label = { Text(stringResource(R.string.tab_groups)) },
                            selected = selectedTab == MainTabRoute.GROUPS,
                            onClick = { selectedTab = MainTabRoute.GROUPS }
                        )
                        item(
                            icon = { Icon(Icons.Rounded.Person, contentDescription = stringResource(R.string.tab_profile)) },
                            label = { Text(stringResource(R.string.tab_profile)) },
                            selected = selectedTab == MainTabRoute.PROFILE,
                            onClick = { selectedTab = MainTabRoute.PROFILE }
                        )
                    }
                ) {
                    when (selectedTab) {
                        MainTabRoute.TODAY -> TodayScreen(
                            state = todayState,
                            onRefresh = todayViewModel::loadToday,
                            onToggleHabit = todayViewModel::toggleHabit,
                            onSaveQuote = {
                                todayViewModel.saveQuoteOfDay()
                                profileViewModel.refresh()
                            },
                            onAddHabit = todayViewModel::addHabit,
                            onSelectHabit = todayViewModel::chooseHabit,
                            onSetDhikrCount = todayViewModel::setDhikrCount,
                            onArchiveHabit = todayViewModel::archiveHabit,
                            onOpenManageHabits = {}
                        )

                        MainTabRoute.GROUPS -> GroupsScreen(
                            state = groupsState,
                            isGuest = authState.user == null,
                            onLoad = groupsViewModel::loadGroups,
                            onCreateGroup = groupsViewModel::createGroup,
                            onJoinGroup = groupsViewModel::joinGroup,
                            onToggleJoinLock = groupsViewModel::toggleJoinLock,
                            onRotateCode = groupsViewModel::rotateCode,
                            onRenameGroup = groupsViewModel::renameGroup,
                            onLeaveGroup = groupsViewModel::leaveGroup,
                            onSignIn = {
                                authRoute = AuthRoute.SIGN_IN
                                authViewModel.openStep(AuthStep.SIGN_IN)
                                rootGraph = RootGraph.AUTH
                            }
                        )

                        MainTabRoute.PROFILE -> ProfileScreen(
                            state = profileState,
                            user = authState.user,
                            onRefresh = profileViewModel::refresh,
                            onSetLanguage = {
                                profileViewModel.setLanguage(it)
                                todayViewModel.updateLocale(it.localeTag)
                            },
                            onSetAppearance = profileViewModel::setAppearance,
                            onSetHabitReminder = profileViewModel::setHabitReminders,
                            onSetQuoteReminder = profileViewModel::setQuoteReminder,
                            onSetGroupReminder = profileViewModel::setGroupReminders,
                            onSetHaptics = profileViewModel::setHaptics,
                            onSetSounds = profileViewModel::setSounds,
                            onClearSavedQuotes = profileViewModel::clearSavedQuotes,
                            onRequestSignIn = {
                                authRoute = AuthRoute.SIGN_IN
                                authViewModel.openStep(AuthStep.SIGN_IN)
                                rootGraph = RootGraph.AUTH
                            },
                            onSignOut = authViewModel::signOut,
                            onOpenSavedQuotes = { profileOverlay = ProfileOverlay.SAVED_QUOTES },
                            onOpenInsights = { profileOverlay = ProfileOverlay.INSIGHTS },
                            debugAuthStatus = if (BuildConfig.DEBUG) container.authRuntimeStatus else null
                        )
                    }
                }

                when (profileOverlay) {
                    ProfileOverlay.NONE -> Unit
                    ProfileOverlay.SAVED_QUOTES -> {
                        com.arystan.almasuly.sunnadandroid.features.profile.SavedQuotesSheet(
                            state = profileState,
                            onDismiss = { profileOverlay = ProfileOverlay.NONE }
                        )
                    }
                    ProfileOverlay.INSIGHTS -> {
                        InsightsScreen(
                            habits = todayState.allHabits,
                            dueHabits = todayState.dueHabits,
                            onClose = { profileOverlay = ProfileOverlay.NONE }
                        )
                    }
                }
            }
        }
    }
}

private enum class ProfileOverlay {
    NONE,
    SAVED_QUOTES,
    INSIGHTS
}
