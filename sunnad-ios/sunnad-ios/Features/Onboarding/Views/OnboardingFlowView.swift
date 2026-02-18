import SwiftUI

struct OnboardingFlowView: View {
    @Binding var step: OnboardingStep
    @Binding var selectedTemplateIDs: Set<String>

    let pendingEmail: String
    let onOpenLanguagePicker: () -> Void
    let onCompleteTemplateSelection: () -> Void
    let onFinishNotifications: () -> Void
    let onCompleteAsGuest: () -> Void
    let onOpenSignIn: () -> Void
    let onOpenSignUp: () -> Void
    let onSignIn: (String, String) -> Void
    let onSignUp: (String, String, String, String) -> Void
    let onOTPVerify: () -> Void

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
                onContinue: onFinishNotifications,
                onSkip: onFinishNotifications
            )
        case .joinGroups:
            JoinGroupsOnboardingView(
                onSignIn: onOpenSignIn,
                onSignUp: onOpenSignUp,
                onGuest: onCompleteAsGuest
            )
        case .signIn:
            SignInView(
                onBack: { step = .joinGroups },
                onSwitchToSignUp: onOpenSignUp,
                onSubmit: onSignIn
            )
        case .signUp:
            SignUpView(
                onBack: { step = .joinGroups },
                onSwitchToSignIn: onOpenSignIn,
                onSubmit: onSignUp
            )
        case .otp:
            OTPVerificationView(
                email: pendingEmail,
                onVerify: onOTPVerify
            )
        }
    }
}
