import SwiftUI

struct SavedQuotesView: View {
    let quotes: [UISavedQuote]

    var body: some View {
        NavigationStack {
            ScreenScaffold(contentTopPadding: 8) {
                if quotes.isEmpty {
                    Card {
                        EmptyStateView(
                            symbol: "book.closed",
                            title: L10n.t("saved_quotes.empty.title"),
                            message: L10n.t("saved_quotes.empty.subtitle"),
                            primaryTitle: L10n.t("common.done"),
                            primaryAction: {}
                        )
                    }
                } else {
                    Card(contentPadding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(quotes.enumerated()), id: \.element.id) { index, quote in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\"\(quote.text)\"")
                                        .font(.body)
                                    Text("— \(quote.author)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(quote.savedAt, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(16)

                                if index < quotes.count - 1 {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.t("saved_quotes.title"))
            .navigationBarTitleDisplayMode(.inline)
            .sunnadSolidBars()
        }
    }
}
