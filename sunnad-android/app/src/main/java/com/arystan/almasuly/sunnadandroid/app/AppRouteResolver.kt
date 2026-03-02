package com.arystan.almasuly.sunnadandroid.app

data class StartupRouteDecision(
    val rootGraph: RootGraph,
    val onboardingRoute: OnboardingRoute? = null,
    val authRoute: AuthRoute? = null
)

fun resolveStartupRoute(
    hasSettingsHydrated: Boolean,
    hasRestoredSession: Boolean,
    hasCompletedOnboarding: Boolean,
    hasAuthenticatedSession: Boolean,
    hasPendingAuthCallback: Boolean,
    hasConfiguredAuth: Boolean = true
): StartupRouteDecision {
    if (!hasSettingsHydrated || !hasRestoredSession) {
        return StartupRouteDecision(rootGraph = RootGraph.LOADING)
    }

    if (!hasCompletedOnboarding) {
        return StartupRouteDecision(
            rootGraph = RootGraph.ONBOARDING,
            onboardingRoute = OnboardingRoute.WELCOME
        )
    }

    if (hasAuthenticatedSession) {
        return StartupRouteDecision(rootGraph = RootGraph.MAIN)
    }

    if (hasPendingAuthCallback && hasConfiguredAuth) {
        return StartupRouteDecision(
            rootGraph = RootGraph.AUTH,
            authRoute = AuthRoute.SIGN_IN
        )
    }

    return StartupRouteDecision(rootGraph = RootGraph.MAIN)
}
