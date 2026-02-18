import SwiftUI

struct SignUpView: View {
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var repeatPassword = ""

    let onBack: () -> Void
    let onSwitchToSignIn: () -> Void
    let onSubmit: (String, String, String, String) -> Void

    private var isValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty &&
        password == repeatPassword
    }

    var body: some View {
        ScreenScaffold(title: nil) {
            pillBackButton
                .padding(.top, 8)

            Text(L10n.t("auth.sign_up"))
                .font(.title.weight(.bold))

            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    LabeledTextFieldRow(
                        label: L10n.t("auth.email"),
                        placeholder: L10n.t("auth.email.placeholder"),
                        value: $email,
                        keyboardType: .emailAddress
                    )
                    .padding(16)

                    Divider().padding(.leading, 16)

                    LabeledTextFieldRow(
                        label: L10n.t("auth.username"),
                        placeholder: L10n.t("auth.username.placeholder"),
                        value: $username
                    )
                    .padding(16)

                    Divider().padding(.leading, 16)

                    LabeledTextFieldRow(
                        label: L10n.t("auth.password"),
                        placeholder: L10n.t("auth.password.placeholder"),
                        value: $password,
                        isSecure: true
                    )
                    .padding(16)

                    Divider().padding(.leading, 16)

                    LabeledTextFieldRow(
                        label: L10n.t("auth.repeat_password"),
                        placeholder: L10n.t("auth.repeat_password.placeholder"),
                        value: $repeatPassword,
                        isSecure: true
                    )
                    .padding(16)
                }
            }

            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    PrimaryButton(title: L10n.t("auth.sign_up"), isEnabled: isValid) {
                        onSubmit(
                            email.trimmingCharacters(in: .whitespacesAndNewlines),
                            username.trimmingCharacters(in: .whitespacesAndNewlines),
                            password,
                            "email"
                        )
                    }
                    .padding(16)

                    Divider().padding(.leading, 16)

                    Button(L10n.t("auth.switch_to_sign_in"), action: onSwitchToSignIn)
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            }

            SectionHeader(title: L10n.t("auth.social"))
            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    Button(L10n.t("auth.apple")) {
                        onSubmit("", "", "", "apple")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 16)

                    Button(L10n.t("auth.google")) {
                        onSubmit("", "", "", "google")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .buttonStyle(.plain)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t("auth.terms"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var pillBackButton: some View {
        Button(L10n.t("common.back"), action: onBack)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(.tertiarySystemFill))
            )
    }
}
