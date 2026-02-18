import SwiftUI

private struct FeedbackToast: Identifiable, Equatable {
    enum Kind {
        case success
        case error

        var icon: String {
            switch self {
            case .success: return "checkmark"
            case .error: return "xmark"
            }
        }

        var color: Color {
            switch self {
            case .success: return SunnadTheme.primary
            case .error: return .red
            }
        }
    }

    let id = UUID()
    let message: String
    let kind: Kind
}

struct FeedbackSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var isSending = false
    @State private var toast: FeedbackToast?
    @State private var attempt = 0

    var body: some View {
        NavigationStack {
            ScreenScaffold(contentTopPadding: 8) {
                HStack(spacing: 10) {
                    Text(L10n.t("profile.send_feedback"))
                        .font(.title2.weight(.bold))
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color(.tertiarySystemFill)))
                    }
                    .accessibilityLabel(L10n.t("common.cancel"))
                }

                Card {
                    TextEditor(text: $text)
                        .frame(minHeight: 160)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                }
            } footer: {
                PrimaryButton(
                    title: isSending ? L10n.t("feedback.sending") : L10n.t("feedback.send"),
                    isEnabled: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending,
                    action: sendFeedback
                )
            }
            .toolbar(.hidden, for: .navigationBar)
            .sunnadSolidBars()
            .overlay(alignment: .top) {
                if let toast {
                    HStack(spacing: 8) {
                        Image(systemName: toast.kind.icon)
                            .foregroundStyle(toast.kind.color)
                        Text(toast.message)
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color(.secondarySystemBackground)))
                    .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 8)
                    .padding(.top, 8)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: toast)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func sendFeedback() {
        isSending = true
        attempt += 1

        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            isSending = false

            if attempt.isMultiple(of: 4) {
                showToast(
                    message: L10n.t("feedback.failed"),
                    kind: .error
                )
                return
            }

            showToast(
                message: L10n.t("feedback.sent"),
                kind: .success
            )

            try? await Task.sleep(nanoseconds: 650_000_000)
            dismiss()
        }
    }

    private func showToast(message: String, kind: FeedbackToast.Kind) {
        let newToast = FeedbackToast(message: message, kind: kind)
        toast = newToast

        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if toast?.id == newToast.id {
                toast = nil
            }
        }
    }
}
