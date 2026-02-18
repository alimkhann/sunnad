import SwiftUI
import UIKit

struct QuoteOfDaySheetView: View {
    let quote: UIQuote
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showsSavedConfirmation = false
    @State private var didApplyDebugState = false

    var body: some View {
        NavigationStack {
            ScreenScaffold(title: nil, titleDisplayMode: .inline) {
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
                        let message = "\"\(quote.text)\" — \(quote.author)"
                        let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)
                        UIApplication.shared.connectedScenes
                            .compactMap { $0 as? UIWindowScene }
                            .flatMap(\.windows)
                            .first?
                            .rootViewController?
                            .present(activityVC, animated: true)
                    }
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
                }
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
}
