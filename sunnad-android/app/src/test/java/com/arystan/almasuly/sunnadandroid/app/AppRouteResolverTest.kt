package com.arystan.almasuly.sunnadandroid.app

import org.junit.Assert.assertEquals
import org.junit.Test

class AppRouteResolverTest {
    @Test
    fun freshInstallOpensOnboardingWelcome() {
        val decision = resolveStartupRoute(
            hasCompletedOnboarding = false,
            hasAuthenticatedSession = false,
            hasPendingAuthCallback = false
        )

        assertEquals(RootGraph.ONBOARDING, decision.rootGraph)
        assertEquals(OnboardingRoute.WELCOME, decision.onboardingRoute)
    }

    @Test
    fun completedOnboardingGuestOpensMainTabs() {
        val decision = resolveStartupRoute(
            hasCompletedOnboarding = true,
            hasAuthenticatedSession = false,
            hasPendingAuthCallback = false
        )

        assertEquals(RootGraph.MAIN, decision.rootGraph)
    }

    @Test
    fun authenticatedSessionOpensMainTabs() {
        val decision = resolveStartupRoute(
            hasCompletedOnboarding = true,
            hasAuthenticatedSession = true,
            hasPendingAuthCallback = false
        )

        assertEquals(RootGraph.MAIN, decision.rootGraph)
    }

    @Test
    fun pendingAuthCallbackOpensAuthGraph() {
        val decision = resolveStartupRoute(
            hasCompletedOnboarding = true,
            hasAuthenticatedSession = false,
            hasPendingAuthCallback = true,
            hasConfiguredAuth = true
        )

        assertEquals(RootGraph.AUTH, decision.rootGraph)
        assertEquals(AuthRoute.SIGN_IN, decision.authRoute)
    }

    @Test
    fun pendingAuthCallbackWithoutConfiguredAuthOpensMain() {
        val decision = resolveStartupRoute(
            hasCompletedOnboarding = true,
            hasAuthenticatedSession = false,
            hasPendingAuthCallback = true,
            hasConfiguredAuth = false
        )

        assertEquals(RootGraph.MAIN, decision.rootGraph)
    }
}
