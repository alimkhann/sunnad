import SwiftUI

struct NotificationSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var preferences: UINotificationPreferences

    var body: some View {
        NavigationStack {
            ScreenScaffold(contentTopPadding: 8) {
                HStack(spacing: 10) {
                    Text(L10n.t("profile.notifications"))
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
                        Toggle(L10n.t("notifications.habit_reminders"), isOn: $preferences.habitReminders)
                            .padding(16)

                        Divider().padding(.leading, 16)

                        Toggle(L10n.t("notifications.quote_reminder"), isOn: $preferences.quoteReminder)
                            .padding(16)

                        Divider().padding(.leading, 16)

                        Toggle(L10n.t("notifications.group_reminders"), isOn: $preferences.groupReminders)
                            .padding(16)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sunnadSolidBars()
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }
}
