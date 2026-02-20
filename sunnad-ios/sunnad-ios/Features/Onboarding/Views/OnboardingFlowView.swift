import SwiftUI

struct OnboardingFlowView: View {
    @Binding var step: OnboardingStep
    @Binding var selectedTemplateIDs: Set<String>

    let pendingEmail: String
    let authErrorMessage: String?
    let authSuccessMessage: String?
    let onOpenLanguagePicker: () -> Void
    let onCompleteTemplateSelection: () -> Void
    let onEnableNotifications: () -> Void
    let onSkipNotifications: () -> Void
    let onCompleteAsGuest: () -> Void
    let onOpenSignIn: () -> Void
    let onOpenSignUp: () -> Void
    let onSignIn: (String, String) -> Void
    let onSignUp: (String, String, String, String) -> Void
    let onOTPVerify: (String) -> Void
    let onResendOTP: () -> Void
    let onOpenForgotPassword: (String) -> Void
    let onClearAuthError: () -> Void

    var body: some View {
        switch step {
        case .welcome:
            WelcomeOnboardingView(
                onChangeLanguage: onOpenLanguagePicker,
                onContinue: { step = .templates }
            )
        case .templates:
            TemplatesOnboardingView(
                selectedIDs: $selectedTemplateIDs,
                onBack: { step = .welcome },
                onContinue: onCompleteTemplateSelection
            )
        case .notifications:
            NotificationsOnboardingView(
                onBack: { step = .templates },
                onContinue: onEnableNotifications,
                onSkip: onSkipNotifications
            )
        case .joinGroups:
            JoinGroupsOnboardingView(
                onBack: { step = .notifications },
                onSignIn: onOpenSignIn,
                onSignUp: onOpenSignUp,
                onGuest: onCompleteAsGuest
            )
        case .signIn:
            SignInView(
                onBack: { step = .joinGroups },
                onSwitchToSignUp: onOpenSignUp,
                onSubmit: onSignIn,
                authErrorMessage: authErrorMessage,
                authSuccessMessage: authSuccessMessage,
                onClearError: onClearAuthError,
                onForgotPassword: onOpenForgotPassword
            )
        case .signUp:
            SignUpView(
                onBack: { step = .joinGroups },
                onSwitchToSignIn: onOpenSignIn,
                onSubmit: onSignUp,
                authErrorMessage: authErrorMessage,
                onClearError: onClearAuthError
            )
        case .otp:
            OTPVerificationView(
                email: pendingEmail,
                onBack: { step = .signUp },
                onVerify: onOTPVerify,
                onResend: onResendOTP,
                authErrorMessage: authErrorMessage,
                authSuccessMessage: authSuccessMessage,
                onClearMessage: onClearAuthError
            )
        }
    }
}
