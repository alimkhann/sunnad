import SwiftUI

struct GroupsView: View {
    let groups: [UIGroup]
    let user: UIUserState
    let habits: [UIHabit]
    let onCreateGroup: () -> Void
    let onJoinGroup: () -> Void
    let onSignIn: () -> Void
    let onUpdateGroupSharing: (UUID, Set<UUID>) -> Void
    let onOpenReminderPlaceholder: () -> Void

    var body: some View {
        Group {
            if user.isGuest {
                guestState
            } else {
                signedInState
            }
        }
        .sunnadSolidBars()
    }

    private var guestState: some View {
        ScreenScaffold(title: L10n.t("tab.groups")) {
            Card {
                EmptyStateView(
                    symbol: "person.2.slash",
                    title: L10n.t("groups.sign_in_required.title"),
                    message: L10n.t("groups.sign_in_required.subtitle"),
                    primaryTitle: L10n.t("auth.sign_in"),
                    primaryAction: onSignIn
                )
            }
        }
    }

    private var signedInState: some View {
        ScreenScaffold(title: L10n.t("tab.groups")) {
            if groups.isEmpty {
                Card {
                    EmptyStateView(
                        symbol: "person.3",
                        title: L10n.t("groups.empty.title"),
                        message: L10n.t("groups.empty.subtitle"),
                        primaryTitle: L10n.t("groups.create"),
                        primaryAction: onCreateGroup,
                        secondaryTitle: L10n.t("groups.join"),
                        secondaryAction: onJoinGroup
                    )
                }
            } else {
                Card(contentPadding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                            NavigationLink {
                                GroupDetailView(
                                    group: group,
                                    habits: habits,
                                    onUpdateSharing: { onUpdateGroupSharing(group.id, $0) },
                                    onReminderTap: onOpenReminderPlaceholder
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.3.fill")
                                        .foregroundStyle(SunnadTheme.primary)
                                        .frame(width: 34, height: 34)
                                        .background(Circle().fill(Color(.secondarySystemGroupedBackground)))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(group.name)
                                            .font(.body)
                                        Text(String(format: L10n.t("groups.members_count"), group.members.count))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.footnote)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)

                            if index < groups.count - 1 {
                                Divider().padding(.leading, 62)
                            }
                        }
                    }
                }
            }

            VStack(spacing: 12) {
                PrimaryButton(title: L10n.t("groups.create"), action: onCreateGroup)
                SecondaryButton(title: L10n.t("groups.join"), action: onJoinGroup)
            }
        }
    }
}
