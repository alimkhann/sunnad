import SwiftUI
import UIKit

struct QuoteOfDaySheetView: View {
    let quote: UIQuote
    let shareLink: URL
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showsSavedConfirmation = false
    @State private var didTriggerShareFlow = false
    @State private var didApplyDebugState = false

    var body: some View {
        NavigationStack {
            ScreenScaffold(title: nil, titleDisplayMode: .inline, contentTopPadding: 8) {
                Card {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("\"\(quote.text)\"")
                            .font(.body)

                        Text("— \(quote.author)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if showsSavedConfirmation {
                            Text(L10n.t("quote.saved_feedback"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                VStack(spacing: 12) {
                    SecondaryButton(title: L10n.t("common.save")) {
                        onSave()
                        withAnimation(.easeOut(duration: 0.18)) {
                            showsSavedConfirmation = true
                        }
                    }

                    PrimaryButton(title: L10n.t("common.share")) {
                        let shareFooter = L10n.t("quote.share.footer")
                            .replacingOccurrences(of: "https://www.sunnad.app", with: shareLink.absoluteString)
                            .replacingOccurrences(of: "https://sunnad.app", with: shareLink.absoluteString)
                        let message = """
                        "\(quote.text)"
                        — \(quote.author)

                        \(shareFooter)
                        """
                        triggerShare(message: message)
                    }
                    .accessibilityIdentifier("quote.share.button")
                    .accessibilityValue(didTriggerShareFlow ? "1" : "0")
                }.frame(maxWidth: .infinity)
            }
            .navigationTitle(L10n.t("today.quote_of_day"))
            .navigationBarTitleDisplayMode(.inline)
            .sunnadSolidBars()
            .presentationDetents([.height(420)])
            .presentationDragIndicator(.visible)
            .onAppear(perform: applyDebugStateIfNeeded)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(L10n.t("common.cancel"))
                    .accessibilityIdentifier("quote.sheet.close")
                }
            }
            .overlay(alignment: .topLeading) {
                EmptyView()
            }
        }
    }

    private func applyDebugStateIfNeeded() {
        #if DEBUG
        guard !didApplyDebugState else {
            return
        }
        didApplyDebugState = true

        let environment = ProcessInfo.processInfo.environment
        let rawValue = environment["SUNNAD_DEBUG_QUOTE_SAVED"]?.lowercased()
        showsSavedConfirmation = rawValue == "1" || rawValue == "true" || rawValue == "yes"
        #endif
    }

    private func triggerShare(message: String) {
        didTriggerShareFlow = true
        #if DEBUG
        if ProcessInfo.processInfo.environment["SUNNAD_UI_TEST_MODE"] == "1" {
            return
        }
        #endif
        SharePresenter.present(message: message)
    }
}

private enum SharePresenter {
    static func present(message: String) {
        let activityController = UIActivityViewController(activityItems: [message], applicationActivities: nil)
        topViewController()?.present(activityController, animated: true)
    }

    private static func topViewController(
        base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    ) -> UIViewController? {
        if let navigation = base as? UINavigationController {
            return topViewController(base: navigation.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}
