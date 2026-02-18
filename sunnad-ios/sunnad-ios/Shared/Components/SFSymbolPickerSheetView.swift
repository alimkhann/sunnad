import SwiftUI

struct SFSymbolPickerSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedSymbol: String
    @State private var searchText = ""

    private var symbols: [String] {
        let base = SFSymbolCatalog.availableNames

        guard !searchText.isEmpty else {
            return base
        }

        return base.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 44), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ScreenScaffold(contentTopPadding: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(L10n.t("common.search"), text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.tertiarySystemBackground))
                )

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(symbols, id: \.self) { symbol in
                        Button {
                            selectedSymbol = symbol
                            dismiss()
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(.tertiarySystemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(symbol == selectedSymbol ? SunnadTheme.primary : SunnadTheme.border, lineWidth: 1)
                                    )

                                Image(systemName: symbol)
                                    .font(.headline)
                                    .foregroundStyle(symbol == selectedSymbol ? SunnadTheme.primary : .primary)
                            }
                            .frame(height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(symbol)
                    }
                }
            }
            .navigationTitle(L10n.t("habit.icon"))
            .navigationBarTitleDisplayMode(.inline)
            .sunnadSolidBars()
            .presentationDetents([.medium, .large])
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
}
