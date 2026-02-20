import SwiftUI

struct ChangePasswordView: View {
    @State private var password = ""
    @State private var repeatPassword = ""

    let onBack: () -> Void
    let onSubmit: (String) -> Void
    var authErrorMessage: String? = nil
    var onClearMessage: (() -> Void)? = nil

    private var passwordStrength: ChangePasswordStrength {
        ChangePasswordStrength(password: password)
    }

    private var canSubmit: Bool {
        password.count >= 8 && password == repeatPassword
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    CompactBackButton(action: onBack)

                    Text(L10n.t("auth.change_password.title"))
                        .font(.title.weight(.bold))

                    Spacer(minLength: 0)
                }

                Spacer()
                    .frame(height: 32)

                Text(L10n.t("auth.change_password.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                if let authErrorMessage, !authErrorMessage.isEmpty {
                    ChangePasswordErrorToast(message: authErrorMessage)
                        .padding(.bottom, 6)
                }

                Card(contentPadding: 0) {
                    VStack(spacing: 0) {
                        LabeledTextFieldRow(
                            label: L10n.t("auth.change_password.new"),
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
                            label: L10n.t("auth.change_password.repeat"),
                            placeholder: L10n.t("auth.repeat_password.placeholder"),
                            value: $repeatPassword,
                            isSecure: true
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                    }
                }

                PrimaryButton(title: L10n.t("auth.change_password.submit"), isEnabled: canSubmit) {
                    onSubmit(password)
                }
                .padding(.top, 2)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, max(10, proxy.safeAreaInsets.bottom + 4))
            .background(SunnadTheme.background.ignoresSafeArea())
            .onChange(of: password) { _, _ in
                onClearMessage?()
            }
            .onChange(of: repeatPassword) { _, _ in
                onClearMessage?()
            }
        }
    }
}

private struct ChangePasswordErrorToast: View {
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

private struct ChangePasswordStrength {
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
