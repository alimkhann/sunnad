import SwiftUI

struct SoundsHapticsSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var preferences: UIFeedbackPreferences

    var body: some View {
        NavigationStack {
            ScreenScaffold(contentTopPadding: 8) {
                HStack(spacing: 10) {
                    Text(L10n.t("profile.sounds_haptics"))
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

                Card(contentPadding: 0) {
                    VStack(spacing: 0) {
                        Toggle(L10n.t("feedback.haptics"), isOn: $preferences.hapticsEnabled)
                            .padding(16)

                        Divider().padding(.leading, 16)

                        Toggle(L10n.t("feedback.sounds"), isOn: $preferences.soundsEnabled)
                            .padding(16)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sunnadSolidBars()
        }
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
    }
}
