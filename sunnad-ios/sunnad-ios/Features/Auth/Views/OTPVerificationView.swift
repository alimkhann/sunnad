import SwiftUI

struct OTPVerificationView: View {
    let email: String
    let onVerify: () -> Void

    @State private var code = ""

    var body: some View {
        ScreenScaffold(title: L10n.t("auth.otp.nav_title"), titleDisplayMode: .inline) {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.t("auth.otp.title"))
                        .font(.headline)
                    Text(String(format: L10n.t("auth.otp.subtitle"), email))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Card {
                TextField(L10n.t("auth.otp.placeholder"), text: $code)
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .font(.title3.monospacedDigit())
            }
        } footer: {
            PrimaryButton(title: L10n.t("auth.otp.verify"), action: onVerify)
        }
    }
}
