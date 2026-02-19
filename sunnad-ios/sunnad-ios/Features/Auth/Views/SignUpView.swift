import SwiftUI

struct SignUpView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var repeatPassword = ""

    let onBack: () -> Void
    let onSwitchToSignIn: () -> Void
    let onSubmit: (String, String, String, String) -> Void
    var showsBackButton: Bool = true

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool {
        !trimmedEmail.isEmpty &&
        !trimmedUsername.isEmpty &&
        !password.isEmpty &&
        password == repeatPassword
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    if showsBackButton {
                        CompactBackButton(action: onBack)
                    }

                    Text(L10n.t("auth.sign_up"))
                        .font(.title.weight(.bold))

                    Spacer(minLength: 0)
                }

                Spacer()
                    .frame(height: 32)

                fieldsCard
                PrimaryButton(title: L10n.t("auth.sign_up"), isEnabled: isValid) {
                    onSubmit(trimmedEmail, trimmedUsername, password, "email")
                }
                .padding(.top, 2)

                Button(L10n.t("auth.switch_to_sign_in"), action: onSwitchToSignIn)
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

                termsLinks
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
                    label: L10n.t("auth.email"),
                    placeholder: L10n.t("auth.email.placeholder"),
                    value: $email,
                    keyboardType: .emailAddress
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 9)

                Divider().padding(.leading, 14)

                LabeledTextFieldRow(
                    label: L10n.t("auth.username"),
                    placeholder: L10n.t("auth.username.placeholder"),
                    value: $username
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 9)

                Divider().padding(.leading, 14)

                LabeledTextFieldRow(
                    label: L10n.t("auth.password"),
                    placeholder: L10n.t("auth.password.placeholder"),
                    value: $password,
                    isSecure: true
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 9)

                Divider().padding(.leading, 14)

                LabeledTextFieldRow(
                    label: L10n.t("auth.repeat_password"),
                    placeholder: L10n.t("auth.repeat_password.placeholder"),
                    value: $repeatPassword,
                    isSecure: true
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
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
                onSubmit("", "", "", "apple")
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
                onSubmit("", "", "", "google")
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

    private var termsLinks: some View {
        VStack(spacing: 4) {
            Text(L10n.t("auth.terms"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Link(L10n.t("auth.terms_link"), destination: URL(string: "https://example.com/terms")!)
                    .underline()
                    .foregroundStyle(SunnadTheme.primary)
                Text(L10n.t("common.and"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Link(L10n.t("auth.privacy_link"), destination: URL(string: "https://example.com/privacy")!)
                    .underline()
                    .foregroundStyle(SunnadTheme.primary)
            }
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
