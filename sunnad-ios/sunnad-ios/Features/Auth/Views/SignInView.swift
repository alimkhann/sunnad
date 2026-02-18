import SwiftUI

struct SignInView: View {
    @State private var username = ""
    @State private var password = ""

    let onBack: () -> Void
    let onSwitchToSignUp: () -> Void
    let onSubmit: (String, String) -> Void

    private var trimmedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScreenScaffold(title: nil) {
            pillBackButton
                .padding(.top, 8)

            Text(L10n.t("auth.sign_in"))
                .font(.title.weight(.bold))

            Card(contentPadding: 0) {
                VStack(spacing: 0) {
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
                }
            }

            Card {
                VStack(spacing: 12) {
                    PrimaryButton(
                        title: L10n.t("auth.sign_in"),
                        isEnabled: !trimmedUsername.isEmpty && !password.isEmpty
                    ) {
                        onSubmit(trimmedUsername, password)
                    }

                    Button(L10n.t("auth.switch_to_sign_up"), action: onSwitchToSignUp)
                        .foregroundStyle(.blue)
                }
            }

            SectionHeader(title: L10n.t("auth.social"))
            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    Button(L10n.t("auth.apple")) {
                        onSubmit("apple_user", "apple")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 16)

                    Button(L10n.t("auth.google")) {
                        onSubmit("google_user", "google")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .buttonStyle(.plain)
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
