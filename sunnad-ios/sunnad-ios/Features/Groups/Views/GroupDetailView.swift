import SwiftUI

struct GroupDetailView: View {
    let group: UIGroup
    let habits: [UIHabit]
    let onUpdateSharing: (Set<UUID>) -> Void
    let onReminderTap: () -> Void

    @State private var expandedMemberIDs: Set<UUID> = []
    @State private var sharedHabitIDs: Set<UUID>

    init(
        group: UIGroup,
        habits: [UIHabit],
        onUpdateSharing: @escaping (Set<UUID>) -> Void,
        onReminderTap: @escaping () -> Void
    ) {
        self.group = group
        self.habits = habits
        self.onUpdateSharing = onUpdateSharing
        self.onReminderTap = onReminderTap
        _sharedHabitIDs = State(initialValue: group.sharedHabitIDs)
    }

    var body: some View {
        ScreenScaffold {
            SectionHeader(title: L10n.t("groups.members"))
            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(group.members.enumerated()), id: \.element.id) { index, member in
                        VStack(spacing: 0) {
                            Button {
                                if expandedMemberIDs.contains(member.id) {
                                    expandedMemberIDs.remove(member.id)
                                } else {
                                    expandedMemberIDs.insert(member.id)
                                }
                            } label: {
                                HStack {
                                    Text(member.name)
                                        .font(.body)
                                    Spacer()
                                    Text("\(member.completedToday)/\(member.totalSharedHabits)")
                                        .foregroundStyle(.secondary)
                                    Image(systemName: expandedMemberIDs.contains(member.id) ? "chevron.down" : "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if expandedMemberIDs.contains(member.id) {
                                if member.sharedHabits.isEmpty {
                                    Text(L10n.t("groups.no_shared_habits"))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 12)
                                } else {
                                    ForEach(Array(member.sharedHabits.enumerated()), id: \.element.id) { memberIndex, habit in
                                        HStack(spacing: 12) {
                                            Image(systemName: habit.habitIconSystemName)
                                                .foregroundStyle(SunnadTheme.primary)
                                                .frame(width: 22)

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(habit.habitTitle)
                                                Text("\(habit.streak) \(L10n.t("today.day_streak"))")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            if habit.completedToday {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(SunnadTheme.primary)
                                            } else {
                                                Button(action: onReminderTap) {
                                                    Image(systemName: "bell.badge")
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)

                                        if memberIndex < member.sharedHabits.count - 1 {
                                            Divider().padding(.leading, 50)
                                        }
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

            SectionHeader(title: L10n.t("groups.sharing"))
            Card(contentPadding: 0) {
                VStack(spacing: 0) {
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
                            Text(habit.displayTitle)
                                .font(.body.weight(.medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        if index < habits.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .sunnadSolidBars()
    }
}
