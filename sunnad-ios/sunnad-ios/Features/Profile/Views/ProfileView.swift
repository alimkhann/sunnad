import SwiftUI

struct ProfileView: View {
    let user: UIUserState
    let habits: [UIHabit]
    let savedQuotes: [UISavedQuote]
    let selectedLanguage: AppLanguage

    let onManageHabits: () -> Void
    let onOpenSavedQuotes: () -> Void
    let onOpenLanguagePicker: () -> Void
    let onOpenInsights: () -> Void
    let onSignIn: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        ScreenScaffold {
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
                profileLinkRow(
                    title: L10n.t("profile.manage_habits"),
                    value: "\(habits.count)",
                    action: onManageHabits
                )
            }

            SectionHeader(title: L10n.t("profile.settings"))
            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    profileLinkRow(
                        title: L10n.t("profile.insights"),
                        action: onOpenInsights
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
                        action: {}
                    )
                    Divider().padding(.leading, 16)
                    profileLinkRow(
                        title: L10n.t("profile.privacy"),
                        action: {}
                    )
                }
            }

            if !user.isGuest {
                Button(role: .destructive, action: onSignOut) {
                    Text(L10n.t("profile.sign_out"))
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 8)
            }

            Card {
                Text(L10n.t("profile.version"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle(L10n.t("tab.profile"))
        .navigationBarTitleDisplayMode(.large)
        .sunnadSolidBars()
    }

    private func profileLinkRow(
        title: String,
        value: String? = nil,
        subtitle: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
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
                    Image(systemName: "chevron.right")
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
        .buttonStyle(.plain)
    }
}
