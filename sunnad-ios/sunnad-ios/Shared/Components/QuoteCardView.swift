import SwiftUI

struct QuoteCardView: View {
    let quote: UIQuote
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.t("quote.card.title"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.yellow)
                        .textCase(.uppercase)

                    Text("\"\(quote.text)\"")
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("— \(quote.author)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.t("quote.card.open"))
        .accessibilityIdentifier("quote.card.open")
    }
}
