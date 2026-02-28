import SwiftUI

struct GroupsView: View {
    @Environment(\.colorScheme) private var colorScheme

    let groups: [UIGroup]
    let user: UIUserState
    let habits: [UIHabit]
    let errorMessage: String?
    let onRefresh: () async -> Void
    let onCreateGroup: () -> Void
    let onJoinGroup: () -> Void
    let onSignIn: () -> Void
    let onOpenGroup: () -> Void
    let onUpdateGroupSharing: (UUID, Set<UUID>) -> Void
    let onToggleOwnHabit: (UUID) -> Void
    let onSendReminder: (UUID, UUID, UUID) async -> GroupNudgeStatus
    let onLeaveGroup: (UUID) -> Void
    let onDeleteGroup: (UUID) -> Void
    let onKickMember: (UUID, UUID) -> Void
    let onRenameGroup: (UUID, String) -> Void
    let onSetJoinLock: (UUID, Bool) -> Void
    let onRotateInviteCode: (UUID) -> Void
    let onRefreshGroup: (UUID) async -> Void
    let onGroupMemberProgressViewed: (String, Int) -> Void
    let currentGroupSharedHabitIDs: (UUID) -> Set<UUID>?

    var body: some View {
        SwiftUI.Group {
            if user.isGuest {
                guestState
            } else {
                signedInState
            }
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
    }

    private var guestState: some View {
        ScreenScaffold(contentTopPadding: 8) {
            pageHeader

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
        ScreenScaffold(contentTopPadding: 8) {
            pageHeader

            if let errorMessage, !errorMessage.isEmpty {
                Card {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .padding(.top, 2)
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

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
                                    onToggleOwnHabit: onToggleOwnHabit,
                                    onSendReminder: { memberID, habitID in
                                        await onSendReminder(group.id, memberID, habitID)
                                    },
                                    onLeaveGroup: { onLeaveGroup(group.id) },
                                    onDeleteGroup: { onDeleteGroup(group.id) },
                                    onKickMember: { onKickMember(group.id, $0) },
                                    onRenameGroup: { onRenameGroup(group.id, $0) },
                                    onSetJoinLock: { onSetJoinLock(group.id, $0) },
                                    onRotateInviteCode: { onRotateInviteCode(group.id) },
                                    onRefresh: { await onRefreshGroup(group.id) },
                                    onMemberProgressViewed: onGroupMemberProgressViewed,
                                    currentSharedHabitIDs: { currentGroupSharedHabitIDs(group.id) }
                                )
                                .id(groupDetailIdentity(for: group))
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

                                    if group.isPending {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.secondary)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.footnote)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            .disabled(group.isPending)
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    onOpenGroup()
                                }
                            )

                            if index < groups.count - 1 {
                                Divider().padding(.leading, 62)
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
        .refreshable {
            await onRefresh()
        }
    }

    private var pageHeader: some View {
        Text(L10n.t("tab.groups"))
            .font(.title.weight(.bold))
    }

    private func groupDetailIdentity(for group: UIGroup) -> String {
        "\(group.id.uuidString)-\(group.members.count)-\(group.joinLocked)-\(group.code)"
    }
}
