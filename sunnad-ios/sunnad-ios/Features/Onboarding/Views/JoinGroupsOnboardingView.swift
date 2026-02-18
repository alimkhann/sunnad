import SwiftUI

struct JoinGroupsOnboardingView: View {
    let onSignIn: () -> Void
    let onSignUp: () -> Void
    let onGuest: () -> Void

    var body: some View {
        ScreenScaffold {
            VStack(spacing: 18) {
                Spacer(minLength: 110)

                Image(systemName: "person.3.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 98, height: 98)
                    .background(Circle().fill(SunnadTheme.primary))

                Text(L10n.t("onboarding.groups.title"))
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(L10n.t("onboarding.groups.subtitle"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)

                Spacer(minLength: 240)
            }
            .frame(maxWidth: .infinity)
        } footer: {
            VStack(spacing: 12) {
                PrimaryButton(title: L10n.t("auth.sign_in"), action: onSignIn)
                SecondaryButton(title: L10n.t("auth.sign_up"), action: onSignUp)
                Button(L10n.t("auth.continue_guest"), action: onGuest)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(SunnadTheme.primary)
            }
        }
    }
}
