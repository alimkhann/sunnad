import SwiftUI

struct SignInView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var username = ""
    @State private var password = ""

    let onBack: () -> Void
    let onSwitchToSignUp: () -> Void
    let onSubmit: (String, String) -> Void

    private var trimmedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmedUsername.isEmpty && !password.isEmpty
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    CompactBackButton(action: onBack)

                    Text(L10n.t("auth.sign_in"))
                        .font(.title.weight(.bold))

                    Spacer(minLength: 0)
                }

                Spacer()
                    .frame(height: 32)

                fieldsCard
                PrimaryButton(title: L10n.t("auth.sign_in"), isEnabled: canSubmit) {
                    onSubmit(trimmedUsername, password)
                }
                .padding(.top, 2)

                Button(L10n.t("auth.switch_to_sign_up"), action: onSwitchToSignUp)
                    .foregroundStyle(SunnadTheme.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)

                Spacer()
                    .frame(height: 24)

                orDivider
                    .padding(.top, 2)

                Spacer()
                    .frame(height: 24)

                socialButtons

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, max(10, proxy.safeAreaInsets.bottom + 4))
            .background(SunnadTheme.background.ignoresSafeArea())
        }
    }

    private var fieldsCard: some View {
        Card(contentPadding: 0) {
            VStack(spacing: 0) {
                LabeledTextFieldRow(
                    label: L10n.t("auth.username"),
                    placeholder: L10n.t("auth.username.placeholder"),
                    value: $username
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                Divider().padding(.leading, 14)

                LabeledTextFieldRow(
                    label: L10n.t("auth.password"),
                    placeholder: L10n.t("auth.password.placeholder"),
                    value: $password,
                    isSecure: true
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
    }

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(SunnadTheme.border)
                .frame(height: 1)
            Text(L10n.t("auth.or_short"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(SunnadTheme.border)
                .frame(height: 1)
        }
    }

    private var socialButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                onSubmit("apple_user", "apple")
            } label: {
                HStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "apple.logo")
                    Text(L10n.t("auth.apple"))
                    Spacer()
                }
                .font(.body.weight(.semibold))
                .padding(.vertical, 13)
                .foregroundStyle(.white)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(.systemGray5), lineWidth: 0.5)
                        .opacity(colorScheme == .dark ? 1 : 0)
                )
            }
            .buttonStyle(.plain)

            Button {
                onSubmit("google_user", "google")
            } label: {
                HStack(spacing: 8) {
                    Spacer()
                    Image("google-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                    Text(L10n.t("auth.google"))
                    Spacer()
                }
                .font(.body.weight(.semibold))
                .padding(.vertical, 13)
                .foregroundStyle(.black)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

}
