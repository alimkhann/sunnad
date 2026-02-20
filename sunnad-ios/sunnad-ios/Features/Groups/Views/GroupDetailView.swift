import SwiftUI
import UIKit

private struct ReminderTarget: Identifiable, Equatable {
    let memberID: UUID
    let memberName: String
    let habitID: UUID
    let habitTitle: String

    var id: String { "\(memberID.uuidString)-\(habitID.uuidString)" }
}

private struct ReminderToast: Identifiable, Equatable {
    enum Style {
        case success
        case error
        case rateLimited

        var icon: String {
            switch self {
            case .success: return "checkmark"
            case .error: return "xmark"
            case .rateLimited: return "exclamationmark"
            }
        }

        var color: Color {
            switch self {
            case .success: return SunnadTheme.primary
            case .error: return .red
            case .rateLimited: return .orange
            }
        }
    }

    let id = UUID()
    let message: String
    let style: Style
}

struct GroupDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let group: UIGroup
    let habits: [UIHabit]
    let onUpdateSharing: (Set<UUID>) -> Void
    let onToggleOwnHabit: (UUID) -> Void
    let onSendReminder: (UUID, UUID) async -> GroupNudgeStatus
    let onLeaveGroup: () -> Void
    let onDeleteGroup: () -> Void
    let onKickMember: (UUID) -> Void
    let onRenameGroup: (String) -> Void
    let onSetJoinLock: (Bool) -> Void
    let onRotateInviteCode: () -> Void
    let onRefresh: () async -> Void
    let currentSharedHabitIDs: () -> Set<UUID>?

    @State private var expandedMemberIDs: Set<UUID> = []
    @State private var sharedHabitIDs: Set<UUID>
    @State private var isEditingSharing = false

    @State private var reminderTarget: ReminderTarget?
    @State private var reminderToast: ReminderToast?
    @State private var ownCompletionOverrides: [UUID: Bool] = [:]
    @State private var pendingKickMember: UIGroupMember?
    @State private var swipedMemberID: UUID?
    @State private var showsLeaveConfirmation = false
    @State private var showsDeleteConfirmation = false
    @State private var showsCopiedCodeSuccess = false
    @State private var copyCodeSequence = 0
    @State private var showsRenameSheet = false

    init(
        group: UIGroup,
        habits: [UIHabit],
        onUpdateSharing: @escaping (Set<UUID>) -> Void,
        onToggleOwnHabit: @escaping (UUID) -> Void,
        onSendReminder: @escaping (UUID, UUID) async -> GroupNudgeStatus,
        onLeaveGroup: @escaping () -> Void,
        onDeleteGroup: @escaping () -> Void,
        onKickMember: @escaping (UUID) -> Void,
        onRenameGroup: @escaping (String) -> Void,
        onSetJoinLock: @escaping (Bool) -> Void,
        onRotateInviteCode: @escaping () -> Void,
        onRefresh: @escaping () async -> Void,
        currentSharedHabitIDs: @escaping () -> Set<UUID>?
    ) {
        self.group = group
        self.habits = habits
        self.onUpdateSharing = onUpdateSharing
        self.onToggleOwnHabit = onToggleOwnHabit
        self.onSendReminder = onSendReminder
        self.onLeaveGroup = onLeaveGroup
        self.onDeleteGroup = onDeleteGroup
        self.onKickMember = onKickMember
        self.onRenameGroup = onRenameGroup
        self.onSetJoinLock = onSetJoinLock
        self.onRotateInviteCode = onRotateInviteCode
        self.onRefresh = onRefresh
        self.currentSharedHabitIDs = currentSharedHabitIDs
        _sharedHabitIDs = State(initialValue: group.sharedHabitIDs)
    }

    var body: some View {
        ScreenScaffold(contentTopPadding: 8) {
            headerRow

            codeChip

            SectionHeader(title: L10n.t("groups.members"))
            membersCard

            SectionHeader(title: L10n.t("groups.sharing"))
            sharingCard

            destructiveActionButton
        }
        .toolbar(.hidden, for: .navigationBar)
        .sunnadSolidBars()
        .refreshable {
            await onRefresh()
        }
        .onAppear {
            sharedHabitIDs = currentSharedHabitIDs() ?? group.sharedHabitIDs
        }
        .onChange(of: group.sharedHabitIDs) { oldValue, newValue in
            sharedHabitIDs = newValue
        }
        .sheet(item: $reminderTarget) { target in
            ReminderPromptSheet(
                memberName: target.memberName,
                habitTitle: target.habitTitle,
                onSend: {
                    sendReminder(to: target)
                    reminderTarget = nil
                },
                onCancel: {
                    reminderTarget = nil
                }
            )
        }
        .sheet(isPresented: $showsRenameSheet) {
            RenameGroupSheet(initialName: group.name) { newName in
                onRenameGroup(newName)
            }
        }
        .overlay(alignment: .top) {
            if let reminderToast {
                HStack(spacing: 10) {
                    Image(systemName: reminderToast.style.icon)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(reminderToast.style.color)
                    Text(reminderToast.message)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .shadow(color: Color.black.opacity(0.16), radius: 16, x: 0, y: 8)
                .padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: reminderToast)
        .alert(
            L10n.t("groups.kick_confirm.title"),
            isPresented: Binding(
                get: { pendingKickMember != nil },
                set: { newValue in
                    if !newValue {
                        pendingKickMember = nil
                    }
                }
            )
        ) {
            Button(L10n.t("groups.kick"), role: .destructive) {
                guard let member = pendingKickMember else { return }
                onKickMember(member.id)
                pendingKickMember = nil
            }
            Button(L10n.t("common.cancel"), role: .cancel) {
                pendingKickMember = nil
            }
        } message: {
            Text(String(format: L10n.t("groups.kick_confirm.message"), pendingKickMember?.name ?? ""))
        }
        .alert(L10n.t("groups.leave_confirm.title"), isPresented: $showsLeaveConfirmation) {
            Button(L10n.t("groups.leave"), role: .destructive) {
                onLeaveGroup()
                dismiss()
            }
            Button(L10n.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.t("groups.leave_confirm.message"))
        }
        .alert(L10n.t("groups.delete_group_confirm.title"), isPresented: $showsDeleteConfirmation) {
            Button(L10n.t("common.delete"), role: .destructive) {
                onDeleteGroup()
                dismiss()
            }
            Button(L10n.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.t("groups.delete_group_confirm.message"))
        }
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            CompactBackButton {
                dismiss()
            }

            Text(group.name)
                .font(.title2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            if isCurrentUserOwner {
                Menu {
                    Button(L10n.t("groups.manage.rename")) {
                        showsRenameSheet = true
                    }
                    Button(group.joinLocked ? L10n.t("groups.manage.unlock") : L10n.t("groups.manage.lock")) {
                        onSetJoinLock(!group.joinLocked)
                    }
                    Button(L10n.t("groups.manage.rotate_code")) {
                        onRotateInviteCode()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3.weight(.semibold))
                }
                .tint(.secondary)
            }
        }
    }

    private var codeChip: some View {
        HStack(spacing: 8) {
            Text(group.code)
                .font(.headline.weight(.semibold))

            if group.joinLocked {
                Image(systemName: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Button {
                UIPasteboard.general.string = group.code
                copyCodeSequence += 1
                let sequence = copyCodeSequence
                withAnimation(.easeInOut(duration: 0.2)) {
                    showsCopiedCodeSuccess = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                    guard sequence == copyCodeSequence else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showsCopiedCodeSuccess = false
                    }
                }
            } label: {
                Image(systemName: showsCopiedCodeSuccess ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(showsCopiedCodeSuccess ? SunnadTheme.primary : .secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: showsCopiedCodeSuccess)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("common.copy"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemFill))
        )
    }

    private var membersCard: some View {
        Card(contentPadding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(group.members.enumerated()), id: \.element.id) { index, member in
                    let isCurrentUser = member.id == resolvedCurrentUserMemberID
                    let progress = memberProgress(for: member, isCurrentUser: isCurrentUser)
                    let canKickMember = canKick(member: member, isCurrentUser: isCurrentUser)
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Text(String(member.name.prefix(1)).uppercased())
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Circle().fill(SunnadTheme.primary))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(member.name)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)

                                    Text("\(progress.completed)/\(progress.total) \(L10n.t("groups.today_suffix"))")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: expandedMemberIDs.contains(member.id) ? "chevron.up" : "chevron.down")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(minHeight: 72)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 10)
                                    .onEnded { value in
                                        guard canKickMember else {
                                            swipedMemberID = nil
                                            return
                                        }

                                        if value.translation.width <= -44 {
                                            swipedMemberID = member.id
                                        } else if value.translation.width >= 20 {
                                            swipedMemberID = nil
                                        }
                                    }
                            )
                            .onTapGesture {
                                if swipedMemberID == member.id {
                                    swipedMemberID = nil
                                    return
                                }

                                swipedMemberID = nil

                                if expandedMemberIDs.contains(member.id) {
                                    expandedMemberIDs.remove(member.id)
                                } else {
                                    expandedMemberIDs.insert(member.id)
                                }
                            }

                            if canKickMember {
                                Button(role: .destructive) {
                                    swipedMemberID = nil
                                    pendingKickMember = member
                                } label: {
                                    Label(L10n.t("groups.kick"), systemImage: "person.fill.xmark")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(width: 104, height: 72)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.white)
                                .frame(width: swipedMemberID == member.id ? 104 : 0, height: 72)
                                .background(.red)
                                .clipped()
                                .opacity(swipedMemberID == member.id ? 1 : 0)
                                .allowsHitTesting(swipedMemberID == member.id)
                                .animation(.easeInOut(duration: 0.18), value: swipedMemberID == member.id)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .clipped()

                        if expandedMemberIDs.contains(member.id) {
                            Divider().padding(.leading, 16)

                            let memberHabits = displayedSharedHabits(for: member, isCurrentUser: isCurrentUser)

                            ForEach(Array(memberHabits.enumerated()), id: \.element.id) { memberIndex, sharedHabit in
                                HStack(spacing: 12) {
                                    Image(systemName: sharedHabit.habitIconSystemName)
                                        .font(.headline)
                                        .foregroundStyle(SunnadTheme.primary)
                                        .frame(width: 34, height: 34)
                                        .background(Circle().fill(Color(.secondarySystemGroupedBackground)))

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(sharedHabit.habitTitle)
                                            .font(.body)
                                        Text("\(sharedHabit.streak) \(L10n.t("today.day_streak"))")
                                        .font(.caption)
                                        .foregroundStyle(.yellow)
                                    }

                                    Spacer()

                                    trailingControl(
                                        for: sharedHabit,
                                        isCurrentUser: isCurrentUser,
                                        member: member
                                    )
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)

                                if memberIndex < memberHabits.count - 1 {
                                    Divider().padding(.leading, 62)
                                }
                            }
                        }

                        if index < group.members.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SunnadTheme.surface)
        )
    }

    private var destructiveActionButton: some View {
        Button(role: .destructive) {
            if isCurrentUserOwner {
                showsDeleteConfirmation = true
            } else {
                showsLeaveConfirmation = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isCurrentUserOwner ? "trash" : "rectangle.portrait.and.arrow.right")
                Text(isCurrentUserOwner ? L10n.t("groups.delete_group") : L10n.t("groups.leave"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var sharingCard: some View {
        Card(contentPadding: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text(String(format: L10n.t("groups.sharing.summary"), sharedHabitIDs.count))
                        .font(.body.weight(.semibold))

                    Spacer()

                    Button(isEditingSharing ? L10n.t("common.done") : L10n.t("common.edit")) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditingSharing.toggle()
                        }
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(SunnadTheme.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if isEditingSharing {
                    Divider().padding(.leading, 16)

                    ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                        Toggle(isOn: Binding(
                            get: { sharedHabitIDs.contains(habit.id) },
                            set: { isOn in
                                if isOn {
                                    sharedHabitIDs.insert(habit.id)
                                } else {
                                    sharedHabitIDs.remove(habit.id)
                                }
                                onUpdateSharing(sharedHabitIDs)
                            }
                        )) {
                            HStack(spacing: 12) {
                                Image(systemName: habit.iconSystemName)
                                    .font(.headline)
                                    .foregroundStyle(SunnadTheme.primary)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(Color(.secondarySystemGroupedBackground)))

                                Text(habit.displayTitle)
                                    .font(.body.weight(.medium))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        if index < habits.count - 1 {
                            Divider().padding(.leading, 62)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func trailingControl(for sharedHabit: UISharedHabit, isCurrentUser: Bool, member: UIGroupMember) -> some View {
        if isCurrentUser {
            Button {
                ownCompletionOverrides[sharedHabit.habitID] = !sharedHabit.completedToday
                onToggleOwnHabit(sharedHabit.habitID)
            } label: {
                Image(systemName: sharedHabit.completedToday ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(sharedHabit.completedToday ? SunnadTheme.primary : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("today.toggle_completion"))
        } else if sharedHabit.completedToday {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(SunnadTheme.primary)
        } else {
            Button {
                reminderTarget = ReminderTarget(
                    memberID: member.id,
                    memberName: member.name,
                    habitID: sharedHabit.habitID,
                    habitTitle: sharedHabit.habitTitle
                )
            } label: {
                Image(systemName: "bell")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("groups.reminder.send"))
        }
    }

    private func displayedSharedHabits(for member: UIGroupMember, isCurrentUser: Bool) -> [UISharedHabit] {
        if isCurrentUser {
            return habits
                .filter { sharedHabitIDs.contains($0.id) }
                .map {
                    UISharedHabit(
                        habitID: $0.id,
                        habitTitle: $0.displayTitle,
                        habitIconSystemName: $0.iconSystemName,
                        completedToday: ownCompletionOverrides[$0.id] ?? $0.completedToday,
                        streak: $0.streak
                    )
                }
        }

        return member.sharedHabits
    }

    private func memberProgress(for member: UIGroupMember, isCurrentUser: Bool) -> (completed: Int, total: Int) {
        guard isCurrentUser else {
            return (member.completedToday, member.totalSharedHabits)
        }

        let ownHabits = displayedSharedHabits(for: member, isCurrentUser: true)
        return (ownHabits.filter(\.completedToday).count, ownHabits.count)
    }

    private var isCurrentUserOwner: Bool {
        group.ownerMemberID == resolvedCurrentUserMemberID
    }

    private func canKick(member: UIGroupMember, isCurrentUser: Bool) -> Bool {
        isCurrentUserOwner && !isCurrentUser
    }

    private var resolvedCurrentUserMemberID: UUID {
        group.currentUserMemberID ?? group.members.first?.id ?? UUID()
    }

    private func sendReminder(to target: ReminderTarget) {
        Task {
            let status = await onSendReminder(target.memberID, target.habitID)
            switch status {
            case .sent:
                showReminderToast(message: L10n.t("groups.reminder.sent"), style: .success)
            case .duplicate:
                showReminderToast(message: L10n.t("groups.reminder.rate_limited"), style: .rateLimited)
            case .forbidden, .error:
                showReminderToast(message: L10n.t("groups.reminder.error"), style: .error)
            }
        }
    }

    private func showReminderToast(message: String, style: ReminderToast.Style) {
        let toast = ReminderToast(message: message, style: style)
        reminderToast = toast

        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if reminderToast?.id == toast.id {
                reminderToast = nil
            }
        }
    }
}

private struct ReminderPromptSheet: View {
    let memberName: String
    let habitTitle: String
    let onSend: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ScreenScaffold(contentTopPadding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.t("groups.reminder.sheet.title"))
                    .font(.title2.weight(.bold))

                Text(String(format: L10n.t("groups.reminder.sheet.message"), memberName, habitTitle))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } footer: {
            VStack(spacing: 10) {
                PrimaryButton(title: L10n.t("groups.reminder.send"), action: onSend)
                SecondaryButton(title: L10n.t("common.cancel"), action: onCancel)
            }
        }
        .presentationDetents([.height(250)])
        .presentationDragIndicator(.visible)
    }
}
