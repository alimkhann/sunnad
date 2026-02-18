import SwiftUI

private enum HabitDetailMode: String, CaseIterable, Identifiable {
    case details
    case counter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .details: return L10n.t("habit.details")
        case .counter: return L10n.t("habit.counter")
        }
    }
}

struct HabitDetailSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var habit: UIHabit

    let user: UIUserState
    let groups: [UIGroup]
    let onDelete: (UUID) -> Void

    @State private var mode: HabitDetailMode = .details

    var body: some View {
        NavigationStack {
            ScreenScaffold(title: nil, titleDisplayMode: .inline) {
                if habit.isDhikr {
                    Card {
                        Picker(L10n.t("habit.mode"), selection: $mode) {
                            ForEach(HabitDetailMode.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if mode == .counter, habit.isDhikr {
                    Card {
                        DhikrCounterView(count: $habit.dhikrCount, target: $habit.dhikrTarget)
                    }
                } else {
                    detailsContent
                }
            }
            .navigationTitle(habit.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .sunnadSolidBars()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.done")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        onDelete(habit.id)
                        dismiss()
                    } label: {
                        Text(L10n.t("common.delete"))
                    }
                }
            }
        }
    }

    private var detailsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: L10n.t("habit.name"))
            Card {
                TextField(L10n.t("habit.name_placeholder"), text: Binding(
                    get: { habit.customTitle ?? habit.displayTitle },
                    set: { habit.customTitle = $0 }
                ))
                .textFieldStyle(.plain)
                .padding(.vertical, 6)
            }

            SectionHeader(title: L10n.t("habit.schedule"))
            Card {
                Picker(L10n.t("habit.schedule"), selection: $habit.schedule) {
                    ForEach(HabitSchedule.allCases) { schedule in
                        Text(L10n.t(schedule.titleKey)).tag(schedule)
                    }
                }
                .pickerStyle(.segmented)

                if habit.schedule == .weekly {
                    WeekdayPickerRow(selectedDays: $habit.weekdays)
                        .padding(.top, 12)
                }
            }

            SectionHeader(title: L10n.t("habit.reminder"))
            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    ReminderToggleRow(
                        title: L10n.t("habit.reminder"),
                        isOn: Binding(
                            get: { habit.reminderTime != nil },
                            set: { isOn in
                                if isOn {
                                    habit.reminderTime = habit.reminderTime ?? UIFixtures.time(hour: 9, minute: 0)
                                } else {
                                    habit.reminderTime = nil
                                }
                            }
                        )
                    )
                    .padding(16)

                    if let reminderTime = habit.reminderTime {
                        Divider().padding(.leading, 16)
                        DatePicker(
                            L10n.t("habit.reminder_time"),
                            selection: Binding(
                                get: { reminderTime },
                                set: { habit.reminderTime = $0 }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .padding(16)
                    }
                }
            }

            if !user.isGuest, !groups.isEmpty {
                SectionHeader(title: L10n.t("groups.sharing"))
                Card {
                    Text(L10n.t("groups.sharing.habit_level_note"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
