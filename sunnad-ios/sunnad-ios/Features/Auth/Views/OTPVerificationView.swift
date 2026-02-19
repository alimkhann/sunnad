import SwiftUI

struct OTPVerificationView: View {
    let email: String
    let onBack: () -> Void
    let onVerify: () -> Void
    var showsBackButton: Bool = true
    var onClose: (() -> Void)? = nil

    @State private var code = ""
    @FocusState private var isCodeFieldFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
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
                        }

                        Text(L10n.t("auth.otp.nav_title"))
                            .font(.largeTitle.weight(.bold))
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 14)

                    Divider()
                }

                VStack(spacing: 0) {
                    VStack(spacing: 24) {
                        VStack(spacing: 4) {
                            Text(L10n.t("auth.otp.subtitle_prefix"))
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Text(email)
                                .font(.title3.weight(.semibold))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)

                        OTPCodeBoxesView(
                            code: $code,
                            isFocused: $isCodeFieldFocused,
                            placeholder: L10n.t("auth.otp.placeholder")
                        )

                        Button(L10n.t("auth.otp.resend")) {}
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(SunnadTheme.primary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 34)

                    Spacer(minLength: 20)

                    PrimaryButton(title: L10n.t("auth.otp.verify"), action: onVerify)
                        .padding(.horizontal, 24)
                        .padding(.bottom, max(16, proxy.safeAreaInsets.bottom + 8))
                }
            }
            .background(SunnadTheme.background.ignoresSafeArea())
            .onAppear {
                #if DEBUG
                if code.isEmpty, let debugCode = ProcessInfo.processInfo.environment["SUNNAD_DEBUG_OTP_CODE"] {
                    code = String(debugCode.filter(\.isNumber).prefix(6))
                }
                #endif
                isCodeFieldFocused = true
            }
        }
    }
}

private struct OTPCodeBoxesView: View {
    @Binding var code: String
    @FocusState.Binding var isFocused: Bool
    let placeholder: String

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .onChange(of: code) { _, newValue in
                    let filtered = newValue.filter(\.isNumber)
                    if filtered != newValue || filtered.count > 6 {
                        code = String(filtered.prefix(6))
                    }
                }
                .frame(width: 1, height: 1)
                .opacity(0.01)

            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    index == focusedIndex ? SunnadTheme.primary.opacity(0.55) : Color(.systemGray4),
                                    lineWidth: 1
                                )
                        )
                        .overlay(
                            Text(digit(at: index))
                                .font(.title2.weight(.semibold))
                                .monospacedDigit()
                        )
                        .frame(width: 46, height: 54)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isFocused = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(placeholder))
        .accessibilityValue(Text(code.isEmpty ? placeholder : code))
    }

    private func digit(at index: Int) -> String {
        guard index < code.count else {
            return ""
        }
        let stringIndex = code.index(code.startIndex, offsetBy: index)
        return String(code[stringIndex])
    }

    private var focusedIndex: Int? {
        guard isFocused, code.count < 6 else {
            return nil
        }
        return code.count
    }
}
