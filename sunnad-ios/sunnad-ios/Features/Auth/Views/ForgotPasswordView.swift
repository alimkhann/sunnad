import SwiftUI

struct ForgotPasswordView: View {
    @State private var email = ""
    @State private var didApplyInitialEmail = false

    let initialEmail: String
    let onBack: () -> Void
    let onSubmit: (String) -> Void
    var authErrorMessage: String? = nil
    var authSuccessMessage: String? = nil
    var onClearMessage: (() -> Void)? = nil

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmedEmail.isEmpty && trimmedEmail.contains("@")
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    CompactBackButton(action: onBack)

                    Text(L10n.t("auth.forgot_password.title"))
                        .font(.title.weight(.bold))

                    Spacer(minLength: 0)
                }

                Spacer()
                    .frame(height: 32)

                Text(L10n.t("auth.forgot_password.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                if let authErrorMessage, !authErrorMessage.isEmpty {
                    ForgotPasswordStatusToast(
                        message: authErrorMessage,
                        icon: "exclamationmark.triangle.fill",
                        accent: .red
                    )
                    .padding(.bottom, 6)
                } else if let authSuccessMessage, !authSuccessMessage.isEmpty {
                    ForgotPasswordStatusToast(
                        message: authSuccessMessage,
                        icon: "checkmark.circle.fill",
                        accent: .green
                    )
                    .padding(.bottom, 6)
                }

                Card(contentPadding: 0) {
                    LabeledTextFieldRow(
                        label: L10n.t("auth.email"),
                        placeholder: L10n.t("auth.email.placeholder"),
                        value: $email,
                        keyboardType: .emailAddress
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }

                PrimaryButton(title: L10n.t("auth.forgot_password.send"), isEnabled: canSubmit) {
                    onSubmit(trimmedEmail)
                }
                .padding(.top, 2)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, max(10, proxy.safeAreaInsets.bottom + 4))
            .background(SunnadTheme.background.ignoresSafeArea())
            .onAppear {
                guard !didApplyInitialEmail else { return }
                email = initialEmail
                didApplyInitialEmail = true
            }
            .onChange(of: email) { _, _ in
                onClearMessage?()
            }
        }
    }
}

private struct ForgotPasswordStatusToast: View {
    let message: String
    let icon: String
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(accent)
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
                .stroke(accent.opacity(0.25), lineWidth: 1)
        )
    }
}
