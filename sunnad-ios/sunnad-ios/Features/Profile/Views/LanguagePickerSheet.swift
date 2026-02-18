import SwiftUI

struct LanguagePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let selected: AppLanguage
    let onSelect: (AppLanguage) -> Void

    var body: some View {
        NavigationStack {
            ScreenScaffold(contentTopPadding: 8) {
                Card(contentPadding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element.id) { index, language in
                            Button {
                                onSelect(language)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(L10n.t(language.nameKey))
                                        .font(.body.weight(.medium))
                                    Spacer()
                                    if language == selected {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(SunnadTheme.primary)
                                    }
                                }
                                .padding(16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if index < AppLanguage.allCases.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.t("profile.language"))
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
            .presentationDetents([.fraction(0.38)])
        }
    }
}
