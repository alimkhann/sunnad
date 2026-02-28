package com.arystan.almasuly.sunnadandroid.app

enum class RootGraph {
    LOADING,
    ONBOARDING,
    AUTH,
    MAIN
}

enum class OnboardingRoute {
    WELCOME,
    TEMPLATES,
    NOTIFICATIONS,
    JOIN_GROUPS,
    SIGN_IN,
    SIGN_UP,
    OTP
}

enum class AuthRoute {
    SIGN_IN,
    SIGN_UP,
    OTP,
    FORGOT_PASSWORD
}

enum class MainTabRoute {
    TODAY,
    GROUPS,
    PROFILE
}
