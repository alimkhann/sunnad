import SwiftUI

struct NotificationsOnboardingView: View {
    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ScreenScaffold {
            VStack(spacing: 18) {
                HStack {
                    CompactBackButton(action: onBack)
                    Spacer()
                    Button(L10n.t("onboarding.welcome.skip"), action: onSkip)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 66)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 98, height: 98)
                    .background(Circle().fill(SunnadTheme.primary))

                Text(L10n.t("onboarding.notifications.title"))
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(L10n.t("onboarding.notifications.subtitle"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)

                Spacer(minLength: 240)
            }
            .frame(maxWidth: .infinity)
        } footer: {
            PrimaryButton(title: L10n.t("onboarding.notifications.enable"), action: onContinue)
        }
    }
}
