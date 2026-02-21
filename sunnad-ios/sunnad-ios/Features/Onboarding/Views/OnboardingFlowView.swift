import SwiftUI

struct OnboardingFlowView: View {
    @Binding var step: OnboardingStep
    @Binding var selectedTemplateIDs: Set<String>

    let pendingEmail: String
    let otpFlowMode: OTPFlowMode
    let otpResendSecondsRemaining: Int
    let authErrorMessage: String?
    let authSuccessMessage: String?
    let googleAuthEnabled: Bool
    let appleAuthEnabled: Bool
    let onOpenLanguagePicker: () -> Void
    let onCompleteTemplateSelection: () -> Void
    let onEnableNotifications: () -> Void
    let onSkipNotifications: () -> Void
    let onCompleteAsGuest: () -> Void
    let onOpenSignIn: () -> Void
    let onOpenSignUp: () -> Void
    let onSignIn: (String, String) -> Void
    let onSignUp: (String, String, String, String) -> Void
    let onGoogleSignIn: () -> Void
    let onGoogleSignUp: () -> Void
    let onAppleSignIn: () -> Void
    let onAppleSignUp: () -> Void
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
                onGoogle: onGoogleSignIn,
                onApple: onAppleSignIn,
                isGoogleEnabled: googleAuthEnabled,
                isAppleEnabled: appleAuthEnabled,
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
                onGoogle: onGoogleSignUp,
                onApple: onAppleSignUp,
                isGoogleEnabled: googleAuthEnabled,
                isAppleEnabled: appleAuthEnabled,
                authErrorMessage: authErrorMessage,
                onClearError: onClearAuthError
            )
        case .otp:
            OTPVerificationView(
                email: pendingEmail,
                flowMode: otpFlowMode,
                resendSecondsRemaining: otpResendSecondsRemaining,
                onBack: { step = .signUp },
                onVerify: onOTPVerify,
                onResend: onResendOTP,
                authErrorMessage: authErrorMessage,
                onClearMessage: onClearAuthError
            )
        }
    }
}
