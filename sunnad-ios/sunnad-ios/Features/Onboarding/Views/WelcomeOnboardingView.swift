import SwiftUI

struct WelcomeOnboardingView: View {
    let onChangeLanguage: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ScreenScaffold {
            HStack {
                Spacer()
                Button(action: onChangeLanguage) {
                    Image(systemName: "globe")
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .padding(11)
                        .background(Circle().fill(Color(.tertiarySystemFill)))
                }
                .accessibilityLabel(L10n.t("profile.language"))
            }
            .padding(.top, 8)

            VStack(spacing: 18) {
                Spacer(minLength: 90)

                Image(systemName: "sun.max.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 102, height: 102)
                    .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(SunnadTheme.primary))

                Text(L10n.t("onboarding.welcome.title"))
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(L10n.t("onboarding.welcome.subtitle"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 22)

                Spacer(minLength: 220)
            }
            .frame(maxWidth: .infinity)
        } footer: {
            PrimaryButton(title: L10n.t("onboarding.welcome.cta"), action: onContinue)
        }
    }
}
