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
    let onGoogle: () -> Void
    let onApple: () -> Void
    var isGoogleEnabled: Bool = true
    var isAppleEnabled: Bool = false
    var authErrorMessage: String? = nil
    var onClearError: (() -> Void)? = nil
    var showsBackButton: Bool = true
    var onClose: (() -> Void)? = nil

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedUsername: String {
        trimmedUsername.lowercased()
    }

    private var usernameIsValid: Bool {
        normalizedUsername.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil
    }

    private var passwordStrength: SignUpPasswordStrength {
        SignUpPasswordStrength(password: password)
    }

    private var isValid: Bool {
        !trimmedEmail.isEmpty &&
        usernameIsValid &&
        password.count >= 8 &&
        password == repeatPassword
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    if showsBackButton {
                        CompactBackButton(action: onBack)
                    } else if let onClose {
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Color(.tertiarySystemFill)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("auth.close.button")
                    }

                    Text(L10n.t("auth.sign_up"))
                        .font(.title.weight(.bold))

                    Spacer(minLength: 0)
                }

                Spacer()
                    .frame(height: 32)

                if let authErrorMessage, !authErrorMessage.isEmpty {
                    AuthSignUpMessageToast(message: authErrorMessage)
                        .padding(.bottom, 6)
                }

                fieldsCard
                PrimaryButton(title: L10n.t("auth.sign_up"), isEnabled: isValid) {
                    onSubmit(trimmedEmail, normalizedUsername, password, "email")
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
            .onChange(of: email) { _, _ in
                onClearError?()
            }
            .onChange(of: username) { _, _ in
                onClearError?()
            }
            .onChange(of: password) { _, _ in
                onClearError?()
            }
            .onChange(of: repeatPassword) { _, _ in
                onClearError?()
            }
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

                Text(L10n.t("profile.edit.username.hint"))
                    .font(.caption)
                    .foregroundStyle(username.isEmpty || usernameIsValid ? Color.secondary : Color.red)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)

                Divider().padding(.leading, 14)

                LabeledTextFieldRow(
                    label: L10n.t("auth.password"),
                    placeholder: L10n.t("auth.password.placeholder"),
                    value: $password,
                    isSecure: true
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 9)

                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { index in
                        Capsule(style: .continuous)
                            .fill(index < passwordStrength.level ? passwordStrength.color : Color(.systemGray5))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

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
                onApple()
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
            .disabled(!isAppleEnabled)
            .opacity(isAppleEnabled ? 1 : 0.55)

            Button {
                onGoogle()
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
            .disabled(!isGoogleEnabled)
            .opacity(isGoogleEnabled ? 1 : 0.55)

            if !isAppleEnabled {
                Text(L10n.t("auth.apple_coming_soon"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
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

private struct AuthSignUpMessageToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.red.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct SignUpPasswordStrength {
    let level: Int
    let color: Color

    init(password: String) {
        let hasLower = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasUpper = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasDigit = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSymbol = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil

        var score = 0
        if password.count >= 8 { score += 1 }
        if hasLower && hasUpper { score += 1 }
        if hasDigit { score += 1 }
        if hasSymbol { score += 1 }
        if password.count >= 12 && score > 0 { score += 1 }

        level = min(max(score, 0), 4)

        switch level {
        case 0...1:
            color = .red
        case 2:
            color = .orange
        case 3:
            color = .yellow
        default:
            color = .green
        }
    }
}
