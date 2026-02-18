import SwiftUI

struct PlaceholderScreen: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let message: String

    var body: some View {
        NavigationStack {
            ScreenScaffold(title: nil, titleDisplayMode: .inline) {
                Card {
                    VStack(spacing: 18) {
                        Image(systemName: "clock.arrow.2.circlepath")
                            .font(.system(size: 42))
                            .foregroundStyle(.secondary)

                        Text(title)
                            .font(.title2.weight(.semibold))

                        Text(message)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .sunnadSolidBars()
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
