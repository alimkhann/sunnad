package com.arystan.almasuly.sunnadandroid.app

import android.net.Uri
import androidx.appcompat.app.AppCompatDelegate
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
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
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.core.os.LocaleListCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.viewmodel.compose.viewModel
import com.onesignal.OneSignal
import com.arystan.almasuly.sunnadandroid.BuildConfig
import com.arystan.almasuly.sunnadandroid.R
import com.arystan.almasuly.sunnadandroid.SunnadApplication
import com.arystan.almasuly.sunnadandroid.features.auth.AuthFlowScreen
import com.arystan.almasuly.sunnadandroid.features.auth.AuthStep
import com.arystan.almasuly.sunnadandroid.features.auth.AuthViewModel
import com.arystan.almasuly.sunnadandroid.features.groups.GroupsScreen
import com.arystan.almasuly.sunnadandroid.features.groups.GroupsViewModel
import com.arystan.almasuly.sunnadandroid.features.insights.InsightsScreen
import com.arystan.almasuly.sunnadandroid.features.insights.InsightsViewModel
import com.arystan.almasuly.sunnadandroid.features.habits.ScheduleScreen
import com.arystan.almasuly.sunnadandroid.features.onboarding.OnboardingFlowScreen
import com.arystan.almasuly.sunnadandroid.features.onboarding.OnboardingTemplateSeed
import com.arystan.almasuly.sunnadandroid.features.profile.ProfileScreen
import com.arystan.almasuly.sunnadandroid.features.profile.ProfileViewModel
import com.arystan.almasuly.sunnadandroid.features.profile.SavedQuotesSheet
import com.arystan.almasuly.sunnadandroid.features.today.TodayScreen
import com.arystan.almasuly.sunnadandroid.features.today.TodayViewModel
import com.arystan.almasuly.sunnadandroid.services.AppAppearance
import com.arystan.almasuly.sunnadandroid.sync.SyncTrigger
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenPadding
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenSurface
import com.arystan.almasuly.sunnadandroid.ui.theme.SunnadTheme
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.util.UUID

@Composable
fun SunnadApp(
    pendingAuthCallback: Uri? = null,
    onAuthCallbackConsumed: () -> Unit = {},
    onRequestNotificationPermission: () -> Unit = {}
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
                syncCoordinator = container.syncCoordinator,
                localDataResetService = container.localDataResetService,
                ownerScopeResolver = container.ownerScopeResolver
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
    val insightsViewModel: InsightsViewModel = viewModel(
        factory = SunnadViewModelFactory {
            InsightsViewModel(
                habitsRepository = container.habitsRepository,
                completionsRepository = container.completionsRepository
            )
        }
    )

    val profileState by profileViewModel.state.collectAsStateWithLifecycle()
    val todayState by todayViewModel.state.collectAsStateWithLifecycle()
    val groupsState by groupsViewModel.state.collectAsStateWithLifecycle()
    val authState by authViewModel.state.collectAsStateWithLifecycle()
    val foregroundSyncScope = rememberCoroutineScope()

    val onboardingCompleted = profileState.settings.onboardingCompleted

    var rootGraph by rememberSaveable { mutableStateOf(RootGraph.LOADING) }
    var onboardingRoute by rememberSaveable { mutableStateOf(OnboardingRoute.WELCOME) }
    var authRoute by rememberSaveable { mutableStateOf(AuthRoute.SIGN_IN) }
    var selectedTab by rememberSaveable { mutableStateOf(MainTabRoute.TODAY) }
    var mainOverlay by rememberSaveable { mutableStateOf(MainOverlayRoute.NONE) }
    var promotedUserId by rememberSaveable { mutableStateOf<String?>(null) }
    var pushTokenUserId by rememberSaveable { mutableStateOf<String?>(null) }
    var registeredPushToken by rememberSaveable { mutableStateOf<String?>(null) }
    var registeredOneSignalId by rememberSaveable { mutableStateOf<String?>(null) }
    var onboardingTemplatesSeeded by rememberSaveable { mutableStateOf(false) }
    var selectedOnboardingTemplateIds by rememberSaveable { mutableStateOf(setOf<String>()) }
    var pendingOnboardingTemplates by remember { mutableStateOf<List<OnboardingTemplateSeed>>(emptyList()) }

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

    LaunchedEffect(profileState.settingsLoaded, profileState.settings.language) {
        if (!profileState.settingsLoaded) return@LaunchedEffect
        todayViewModel.updateLocale(profileState.settings.language)
        AppCompatDelegate.setApplicationLocales(
            LocaleListCompat.forLanguageTags(profileState.settings.language)
        )
    }

    LaunchedEffect(
        profileState.settingsLoaded,
        profileState.settings.habitRemindersEnabled,
        profileState.settings.quoteReminderEnabled,
        profileState.settings.language,
        todayState.allHabits,
        todayState.dueHabits
    ) {
        if (!profileState.settingsLoaded) return@LaunchedEffect
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

    LaunchedEffect(authState.user?.id, profileState.settingsLoaded, profileState.settings.groupRemindersEnabled) {
        val signedInUser = authState.user
        if (signedInUser != null) {
            runCatching { OneSignal.login(signedInUser.id.toString()) }
            if (profileState.settingsLoaded && !profileState.settings.groupRemindersEnabled) {
                val oneSignalSubscriptionId = runCatching {
                    OneSignal.User.pushSubscription.id
                }.getOrNull()?.trim().takeUnless { it.isNullOrBlank() }
                val oneSignalToken = runCatching {
                    OneSignal.User.pushSubscription.token
                }.getOrNull()?.trim().takeUnless { it.isNullOrBlank() }
                val token = registeredPushToken
                    ?: oneSignalToken
                    ?: oneSignalSubscriptionId?.let { "onesignal-subscription:$it" }
                if (token != null) {
                    container.pushTokenSyncService.clearToken(
                        userId = signedInUser.id,
                        token = token,
                        oneSignalSubscriptionId = registeredOneSignalId ?: oneSignalSubscriptionId
                    )
                }
                pushTokenUserId = signedInUser.id.toString()
                registeredPushToken = null
                registeredOneSignalId = null
                return@LaunchedEffect
            }
            repeat(8) {
                val oneSignalSubscriptionId = runCatching {
                    OneSignal.User.pushSubscription.id
                }.getOrNull()?.trim().takeUnless { it.isNullOrBlank() }

                val oneSignalToken = runCatching {
                    OneSignal.User.pushSubscription.token
                }.getOrNull()?.trim().takeUnless { it.isNullOrBlank() }

                val effectiveToken = oneSignalToken ?: oneSignalSubscriptionId?.let { "onesignal-subscription:$it" }
                if (!effectiveToken.isNullOrBlank()) {
                    if (
                        pushTokenUserId == signedInUser.id.toString() &&
                        registeredPushToken == effectiveToken &&
                        registeredOneSignalId == oneSignalSubscriptionId
                    ) {
                        return@LaunchedEffect
                    }
                    container.pushTokenSyncService.registerToken(
                        userId = signedInUser.id,
                        token = effectiveToken,
                        oneSignalSubscriptionId = oneSignalSubscriptionId
                    )
                    pushTokenUserId = signedInUser.id.toString()
                    registeredPushToken = effectiveToken
                    registeredOneSignalId = oneSignalSubscriptionId
                    return@LaunchedEffect
                }
                delay(1200)
            }

            val debugPushToken = BuildConfig.SUNNAD_DEBUG_PUSH_TOKEN.trim()
            if (debugPushToken.isNotBlank()) {
                container.pushTokenSyncService.registerToken(signedInUser.id, debugPushToken)
                pushTokenUserId = signedInUser.id.toString()
                registeredPushToken = debugPushToken
                registeredOneSignalId = null
            }
        } else {
            runCatching { OneSignal.logout() }
            val previousId = pushTokenUserId
            val token = registeredPushToken
            if (previousId != null && token != null) {
                val previousUuid = runCatching { UUID.fromString(previousId) }.getOrNull()
                if (previousUuid != null) {
                    container.pushTokenSyncService.clearToken(
                        userId = previousUuid,
                        token = token,
                        oneSignalSubscriptionId = registeredOneSignalId
                    )
                }
            }
            pushTokenUserId = null
            registeredPushToken = null
            registeredOneSignalId = null
        }
    }

    LaunchedEffect(mainOverlay, todayState.dueHabits, todayState.allHabits, todayState.completionRevision) {
        if (mainOverlay == MainOverlayRoute.INSIGHTS) {
            insightsViewModel.load()
        }
    }

    LaunchedEffect(todayState.completionRevision) {
        if (todayState.completionRevision == 0L) return@LaunchedEffect
        profileViewModel.refresh()
        if (mainOverlay == MainOverlayRoute.INSIGHTS) {
            insightsViewModel.load()
        }
    }

    LaunchedEffect(
        onboardingCompleted,
        authState.user,
        authState.step,
        authState.otpFlowMode,
        authState.hasRestoredSession,
        profileState.settingsLoaded,
        rootGraph
    ) {
        container.ownerScopeResolver.setSignedInUserId(authState.user?.id)
        container.syncCoordinator.setSignedInUserId(authState.user?.id)
        val userId = authState.user?.id
        if (userId != null && promotedUserId != userId.toString()) {
            container.syncCoordinator.promoteGuestDataIfNeeded(userId)
            container.syncCoordinator.runSyncCycle(SyncTrigger.AUTH)
            promotedUserId = userId.toString()
        }
        val hasPendingRecoveryPasswordUpdate =
            authState.step == AuthStep.CHANGE_PASSWORD &&
                authState.otpFlowMode == com.arystan.almasuly.sunnadandroid.features.auth.OtpFlowMode.RECOVERY

        when {
            rootGraph == RootGraph.LOADING -> {
                val startup = resolveStartupRoute(
                    hasSettingsHydrated = profileState.settingsLoaded,
                    hasRestoredSession = authState.hasRestoredSession,
                    hasCompletedOnboarding = onboardingCompleted,
                    hasAuthenticatedSession = authState.user != null,
                    hasPendingAuthCallback = pendingAuthCallback != null,
                    hasConfiguredAuth = authState.isConfigured
                )
                rootGraph = startup.rootGraph
                startup.onboardingRoute?.let { onboardingRoute = it }
                startup.authRoute?.let { authRoute = it }
            }

            !profileState.settingsLoaded || !authState.hasRestoredSession -> {
                rootGraph = RootGraph.LOADING
            }

            authState.user != null && !hasPendingRecoveryPasswordUpdate -> {
                if (!onboardingTemplatesSeeded && pendingOnboardingTemplates.isNotEmpty()) {
                    todayViewModel.seedHabitsFromTemplates(pendingOnboardingTemplates)
                    onboardingTemplatesSeeded = true
                }
                pendingOnboardingTemplates = emptyList()
                selectedOnboardingTemplateIds = emptySet()
                if (!profileState.settings.onboardingCompleted) {
                    profileViewModel.setOnboardingCompleted(true)
                }
                rootGraph = RootGraph.MAIN
                selectedTab = MainTabRoute.TODAY
            }

            rootGraph == RootGraph.AUTH && !authState.isConfigured -> {
                rootGraph = RootGraph.MAIN
                selectedTab = MainTabRoute.TODAY
            }

            !onboardingCompleted -> {
                rootGraph = RootGraph.ONBOARDING
            }
        }
    }

    LifecycleEventEffect(Lifecycle.Event.ON_START) {
        if (rootGraph != RootGraph.MAIN || authState.user == null || !authState.hasRestoredSession) {
            return@LifecycleEventEffect
        }
        foregroundSyncScope.launch {
            container.syncCoordinator.runSyncCycle(SyncTrigger.FOREGROUND)
            todayViewModel.loadToday()
            groupsViewModel.loadGroups()
            profileViewModel.refresh()
        }
    }

    LaunchedEffect(authState.user, mainOverlay) {
        if (mainOverlay == MainOverlayRoute.AUTH && authState.user != null) {
            mainOverlay = MainOverlayRoute.NONE
            selectedTab = MainTabRoute.TODAY
        }
    }

    SunnadTheme(forcedDarkTheme = darkThemeMode) {
        when (rootGraph) {
            RootGraph.LOADING -> {
                SunnadScreenSurface {
                    Row(
                        modifier = Modifier
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
                                onboardingTemplatesSeeded = true
                                pendingOnboardingTemplates = emptyList()
                                selectedOnboardingTemplateIds = emptySet()
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
                            onEnableNotifications = onRequestNotificationPermission,
                            onSkipNotifications = {},
                            selectedLanguage = profileState.language,
                            selectedTemplateIds = selectedOnboardingTemplateIds,
                            onSelectedTemplateIdsChange = {
                                selectedOnboardingTemplateIds = it
                            },
                            onSelectedTemplatesChange = {
                                pendingOnboardingTemplates = it
                                onboardingTemplatesSeeded = false
                            }
                        )
                    }

                    OnboardingRoute.SIGN_IN,
                    OnboardingRoute.SIGN_UP,
                    OnboardingRoute.OTP,
                    OnboardingRoute.FORGOT_PASSWORD -> {
                        val targetStep = when (onboardingRoute) {
                            OnboardingRoute.SIGN_IN -> AuthStep.SIGN_IN
                            OnboardingRoute.SIGN_UP -> AuthStep.SIGN_UP
                            OnboardingRoute.OTP -> AuthStep.OTP
                            OnboardingRoute.FORGOT_PASSWORD -> AuthStep.FORGOT_PASSWORD
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
                                    AuthStep.OTP -> if (authState.otpFlowMode == com.arystan.almasuly.sunnadandroid.features.auth.OtpFlowMode.RECOVERY) {
                                        OnboardingRoute.FORGOT_PASSWORD
                                    } else {
                                        OnboardingRoute.SIGN_UP
                                    }
                                    AuthStep.FORGOT_PASSWORD -> OnboardingRoute.SIGN_IN
                                    AuthStep.CHANGE_PASSWORD -> OnboardingRoute.OTP
                                }
                            },
                            onClose = null,
                            onOpenStep = {
                                onboardingRoute = when (it) {
                                    AuthStep.SIGN_IN -> OnboardingRoute.SIGN_IN
                                    AuthStep.SIGN_UP -> OnboardingRoute.SIGN_UP
                                    AuthStep.OTP,
                                    AuthStep.CHANGE_PASSWORD -> OnboardingRoute.OTP
                                    AuthStep.FORGOT_PASSWORD -> OnboardingRoute.FORGOT_PASSWORD
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
                            onUpdatePassword = authViewModel::updatePassword,
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
                    AuthRoute.CHANGE_PASSWORD -> AuthStep.CHANGE_PASSWORD
                }
                LaunchedEffect(forcedStep) {
                    authViewModel.openStep(forcedStep)
                }
                AuthFlowScreen(
                    state = authState,
                    onBack = when (authState.step) {
                        AuthStep.SIGN_IN, AuthStep.SIGN_UP -> null
                        AuthStep.FORGOT_PASSWORD -> ({ authViewModel.openStep(AuthStep.SIGN_IN) })
                        AuthStep.CHANGE_PASSWORD -> ({ authViewModel.openStep(AuthStep.OTP) })
                        AuthStep.OTP -> {
                            if (authState.otpFlowMode == com.arystan.almasuly.sunnadandroid.features.auth.OtpFlowMode.RECOVERY) {
                                ({ authViewModel.openStep(AuthStep.FORGOT_PASSWORD) })
                            } else {
                                ({ authViewModel.openStep(AuthStep.SIGN_UP) })
                            }
                        }
                    },
                    onClose = { rootGraph = RootGraph.MAIN },
                    onOpenStep = { step ->
                        authRoute = when (step) {
                            AuthStep.SIGN_IN -> AuthRoute.SIGN_IN
                            AuthStep.SIGN_UP -> AuthRoute.SIGN_UP
                            AuthStep.OTP -> AuthRoute.OTP
                            AuthStep.FORGOT_PASSWORD -> AuthRoute.FORGOT_PASSWORD
                            AuthStep.CHANGE_PASSWORD -> AuthRoute.CHANGE_PASSWORD
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
                    onUpdatePassword = authViewModel::updatePassword,
                    onContinueAsGuest = { rootGraph = RootGraph.MAIN }
                )
            }

            RootGraph.MAIN -> {
                Box(modifier = Modifier.fillMaxSize()) {
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
                                onAddTemplates = todayViewModel::seedHabitsFromTemplates,
                                onSelectHabit = todayViewModel::chooseHabit,
                                onSetDhikrCount = todayViewModel::setDhikrCount,
                                onSaveHabit = todayViewModel::updateHabit,
                                onDeleteHabit = todayViewModel::deleteHabit,
                                onOpenManageHabits = {
                                    mainOverlay = MainOverlayRoute.SCHEDULE
                                }
                            )

                            MainTabRoute.GROUPS -> GroupsScreen(
                                state = groupsState,
                                isGuest = authState.user == null,
                                dueHabits = todayState.dueHabits,
                                allHabits = todayState.allHabits,
                                onLoad = groupsViewModel::loadGroups,
                                onCreateGroup = groupsViewModel::createGroup,
                                onJoinGroup = groupsViewModel::joinGroup,
                                onToggleJoinLock = groupsViewModel::toggleJoinLock,
                                onRotateCode = groupsViewModel::rotateCode,
                                onRenameGroup = groupsViewModel::renameGroup,
                                onLeaveGroup = groupsViewModel::leaveGroup,
                                onDeleteGroup = groupsViewModel::deleteGroup,
                                onKickMember = groupsViewModel::kickMember,
                                onSetProgressDisplayMode = groupsViewModel::setProgressDisplayMode,
                                onUpdateSharing = groupsViewModel::updateSharing,
                                onToggleOwnHabit = todayViewModel::toggleHabit,
                                onSendNudge = groupsViewModel::sendNudge,
                                onSignIn = {
                                    authViewModel.openStep(AuthStep.SIGN_IN)
                                    mainOverlay = MainOverlayRoute.AUTH
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
                                onDeleteData = {
                                    profileViewModel.clearAllLocalData()
                                    todayViewModel.loadToday()
                                    groupsViewModel.loadGroups()
                                },
                                onDeleteAccount = {
                                    authViewModel.deleteAccount()
                                    profileViewModel.clearAllLocalData()
                                    todayViewModel.loadToday()
                                    groupsViewModel.loadGroups()
                                },
                                onEditProfile = { username ->
                                    authViewModel.updateProfile(username)
                                    groupsViewModel.loadGroups()
                                },
                                onUploadAvatar = { data, mimeType ->
                                    authViewModel.uploadAvatar(data, mimeType)
                                    groupsViewModel.loadGroups()
                                },
                                onRemoveAvatar = {
                                    authViewModel.removeAvatar()
                                    groupsViewModel.loadGroups()
                                },
                                onRequestSignIn = {
                                    authViewModel.openStep(AuthStep.SIGN_IN)
                                    mainOverlay = MainOverlayRoute.AUTH
                                },
                                onSignOut = authViewModel::signOut,
                                onChangePassword = {
                                    authViewModel.openStep(AuthStep.CHANGE_PASSWORD)
                                    mainOverlay = MainOverlayRoute.AUTH
                                },
                                onOpenSavedQuotes = { mainOverlay = MainOverlayRoute.SAVED_QUOTES },
                                onOpenInsights = { mainOverlay = MainOverlayRoute.INSIGHTS },
                                onOpenManageHabits = { mainOverlay = MainOverlayRoute.SCHEDULE },
                                debugAuthStatus = if (BuildConfig.DEBUG) container.authRuntimeStatus else null
                            )
                        }
                    }

                    when (mainOverlay) {
                        MainOverlayRoute.NONE -> Unit
                        MainOverlayRoute.SAVED_QUOTES -> {
                            SavedQuotesSheet(
                                state = profileState,
                                onDismiss = { mainOverlay = MainOverlayRoute.NONE }
                            )
                        }

                        MainOverlayRoute.INSIGHTS -> {
                            InsightsScreen(
                                viewModel = insightsViewModel,
                                onClose = { mainOverlay = MainOverlayRoute.NONE }
                            )
                        }

                        MainOverlayRoute.AUTH -> {
                            AuthFlowScreen(
                                state = authState,
                                onBack = when (authState.step) {
                                    AuthStep.SIGN_IN, AuthStep.SIGN_UP -> null
                                    AuthStep.FORGOT_PASSWORD -> ({ authViewModel.openStep(AuthStep.SIGN_IN) })
                                    AuthStep.CHANGE_PASSWORD -> ({ authViewModel.openStep(AuthStep.OTP) })
                                    AuthStep.OTP -> {
                                        if (authState.otpFlowMode == com.arystan.almasuly.sunnadandroid.features.auth.OtpFlowMode.RECOVERY) {
                                            ({ authViewModel.openStep(AuthStep.FORGOT_PASSWORD) })
                                        } else {
                                            ({ authViewModel.openStep(AuthStep.SIGN_UP) })
                                        }
                                    }
                                },
                                onClose = { mainOverlay = MainOverlayRoute.NONE },
                                onOpenStep = authViewModel::openStep,
                                onSignIn = authViewModel::signIn,
                                onSignUp = authViewModel::signUp,
                                onRequestPasswordReset = authViewModel::requestPasswordReset,
                                onVerifyOtp = authViewModel::verifyOtp,
                                onResendOtp = authViewModel::resendOtp,
                                onGoogleSignIn = authViewModel::signInWithGoogle,
                                onAppleSignIn = authViewModel::signInWithApplePrewired,
                                onUpdatePassword = authViewModel::updatePassword,
                                onContinueAsGuest = { mainOverlay = MainOverlayRoute.NONE },
                                closeOnLeft = true
                            )
                        }

                        MainOverlayRoute.SCHEDULE -> {
                            ScheduleScreen(
                                habits = todayState.allHabits,
                                streakByHabitId = todayState.habitStreakById,
                                onClose = { mainOverlay = MainOverlayRoute.NONE },
                                onSelectHabit = { habitId ->
                                    selectedTab = MainTabRoute.TODAY
                                    mainOverlay = MainOverlayRoute.NONE
                                    todayViewModel.chooseHabit(habitId)
                                },
                                onReorderHabits = todayViewModel::reorderHabits
                            )
                        }
                    }
                }
            }
        }
    }
}
