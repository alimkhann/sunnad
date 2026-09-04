import SwiftUI

struct WelcomeOnboardingView: View {
    let onChangeLanguage: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ScreenScaffold {
            HStack {
                Button(L10n.t("onboarding.welcome.skip"), action: onSkip)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("onboarding.skip.button")
                Spacer()
                Button(action: onChangeLanguage) {
                    Image(systemName: "globe")
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                        .padding(11)
                        .background(Circle().fill(Color(.tertiarySystemFill)))
                }
                .accessibilityLabel(L10n.t("profile.language"))
            }
            .padding(.top, 8)

            VStack(spacing: 18) {
                Spacer(minLength: 20)

                ZStack {
                    Circle()
                        .fill(SunnadTheme.primary.opacity(0.10))
                        .frame(width: 132, height: 132)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [SunnadTheme.primary, SunnadTheme.primary.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                        .shadow(color: SunnadTheme.primary.opacity(0.24), radius: 18, y: 8)
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }

                Text("Adat")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(L10n.t("onboarding.welcome.value"))
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Label(L10n.t("onboarding.welcome.private_start"), systemImage: "lock.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)

                Card {
                    Text(L10n.t("onboarding.welcome.quote"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity)
        } footer: {
            PrimaryButton(title: L10n.t("onboarding.welcome.cta"), action: onContinue)
                .accessibilityIdentifier("onboarding.get_started.button")
        }
    }

}
