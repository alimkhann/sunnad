import SwiftUI

struct ProfileView: View {
    @Environment(\.colorScheme) private var colorScheme

    let user: UIUserState
    let habits: [UIHabit]
    let savedQuotes: [UISavedQuote]
    let selectedLanguage: AppLanguage
    @Binding var selectedAppearance: AppAppearance
    @Binding var notificationPreferences: UINotificationPreferences

    let onManageHabits: () -> Void
    let onOpenSavedQuotes: () -> Void
    let onOpenLanguagePicker: () -> Void
    let onOpenInsights: () -> Void
    let onSignIn: () -> Void
    let onSignOut: () -> Void
    let onChangePassword: () -> Void
    let onDeleteData: () -> Void
    let onDeleteAccount: () -> Void
    let privacyURL: URL
    let helpURL: URL

    @State private var showsNotificationSettings = false
    @State private var showsFeedback = false
    @State private var showsAppearancePicker = false
    @State private var confirmsSignOut = false
    @State private var confirmsDeleteData = false
    @State private var confirmsDeleteAccount = false

    var body: some View {
        ScreenScaffold(contentTopPadding: 8) {
            Text(L10n.t("tab.profile"))
                .font(.title.weight(.bold))

            SectionHeader(title: L10n.t("profile.account"))

            Card(contentPadding: 0) {
                if user.isGuest {
                    profileLinkRow(
                        title: L10n.t("profile.guest"),
                        value: nil,
                        subtitle: L10n.t("profile.tap_sign_in"),
                        action: onSignIn
                    )
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(SunnadTheme.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.name ?? "")
                                .font(.body.weight(.semibold))
                            Text(user.email ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                }
            }

            SectionHeader(title: L10n.t("profile.saved"))
            Card(contentPadding: 0) {
                profileLinkRow(
                    title: L10n.t("profile.saved_quotes"),
                    value: "\(savedQuotes.count)",
                    action: onOpenSavedQuotes
                )
            }

            SectionHeader(title: L10n.t("profile.habits"))
            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    profileLinkRow(
                        title: L10n.t("profile.manage_habits"),
                        value: "\(habits.count)",
                        action: onManageHabits
                    )
                    Divider().padding(.leading, 16)
                    profileLinkRow(
                        title: L10n.t("profile.insights"),
                        action: onOpenInsights
                    )
                }
            }

            SectionHeader(title: L10n.t("profile.settings"))
            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    profileLinkRow(
                        title: L10n.t("profile.appearance"),
                        value: L10n.t(selectedAppearance.nameKey),
                        action: { showsAppearancePicker = true }
                    )
                    Divider().padding(.leading, 16)
                    profileLinkRow(
                        title: L10n.t("profile.language"),
                        value: L10n.t(selectedLanguage.nameKey),
                        action: onOpenLanguagePicker
                    )
                    Divider().padding(.leading, 16)
                    profileLinkRow(
                        title: L10n.t("profile.notifications"),
                        action: { showsNotificationSettings = true }
                    )
                    if !user.isGuest {
                        Divider().padding(.leading, 16)
                        profileLinkRow(
                            title: L10n.t("profile.change_password"),
                            action: onChangePassword
                        )
                    }
                    Divider().padding(.leading, 16)
                    externalLinkRow(
                        title: L10n.t("profile.privacy"),
                        url: privacyURL
                    )
                }
            }

            SectionHeader(title: L10n.t("profile.support"))
            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    externalLinkRow(
                        title: L10n.t("profile.help_faq"),
                        url: helpURL
                    )
                    Divider().padding(.leading, 16)
                    profileLinkRow(
                        title: L10n.t("profile.send_feedback"),
                        action: { showsFeedback = true }
                    )
                }
            }

            SectionHeader(title: L10n.t("profile.danger_zone"))
            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    if !user.isGuest {
                        dangerRow(
                            title: L10n.t("profile.sign_out"),
                            icon: "rectangle.portrait.and.arrow.right",
                            action: { confirmsSignOut = true }
                        )
                        Divider().padding(.leading, 16)
                        dangerRow(
                            title: L10n.t("profile.delete_account"),
                            icon: "person.crop.circle.badge.xmark",
                            action: { confirmsDeleteAccount = true }
                        )
                    } else {
                        dangerRow(
                            title: L10n.t("profile.delete_data"),
                            icon: "trash",
                            action: { confirmsDeleteData = true }
                        )
                    }
                }
            }

            Text(L10n.t("profile.version"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sunnadSolidBars()
        .background(alignment: .top) {
            if colorScheme == .dark {
                Color.black
                    .frame(height: 96)
                    .ignoresSafeArea(edges: .top)
            }
        }
        .sheet(isPresented: $showsNotificationSettings) {
            NotificationSettingsSheet(preferences: $notificationPreferences)
        }
        .sheet(isPresented: $showsFeedback) {
            FeedbackSheetView()
        }
        .confirmationDialog(
            L10n.t("profile.appearance"),
            isPresented: $showsAppearancePicker,
            titleVisibility: .visible
        ) {
            ForEach(AppAppearance.allCases) { option in
                Button(L10n.t(option.nameKey)) {
                    selectedAppearance = option
                }
            }
            Button(L10n.t("common.cancel"), role: .cancel) {}
        }
        .alert(L10n.t("profile.sign_out"), isPresented: $confirmsSignOut) {
            Button(L10n.t("common.cancel"), role: .cancel) {}
            Button(L10n.t("profile.sign_out"), role: .destructive) {
                onSignOut()
            }
        } message: {
            Text(L10n.t("profile.sign_out.confirm"))
        }
        .alert(L10n.t("profile.delete_data"), isPresented: $confirmsDeleteData) {
            Button(L10n.t("common.cancel"), role: .cancel) {}
            Button(L10n.t("profile.delete_data"), role: .destructive) {
                onDeleteData()
            }
        } message: {
            Text(L10n.t("profile.delete_data.confirm"))
        }
        .alert(L10n.t("profile.delete_account"), isPresented: $confirmsDeleteAccount) {
            Button(L10n.t("common.cancel"), role: .cancel) {}
            Button(L10n.t("profile.delete_account"), role: .destructive) {
                onDeleteAccount()
            }
        } message: {
            Text(L10n.t("profile.delete_account.confirm"))
        }
    }

    private func profileLinkRow(
        title: String,
        value: String? = nil,
        subtitle: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            rowContent(title: title, value: value, subtitle: subtitle, trailingSymbol: "chevron.right")
        }
        .buttonStyle(.plain)
    }

    private func externalLinkRow(title: String, url: URL) -> some View {
        Link(destination: url) {
            rowContent(title: title, trailingSymbol: "arrow.up.right")
        }
        .buttonStyle(.plain)
    }

    private func rowContent(
        title: String,
        value: String? = nil,
        subtitle: String? = nil,
        trailingSymbol: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                if let value {
                    Text(value)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: trailingSymbol)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(SunnadTheme.primary)
            }
        }
        .padding(16)
        .contentShape(Rectangle())
    }

    private func dangerRow(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.red)
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.red)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
