import SwiftUI

struct ScheduleScreenView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var habits: [UIHabit]

    let onSelectHabit: (UIHabit) -> Void
    let onOpenWeekPlaceholder: () -> Void
    let onOpenMonthPlaceholder: () -> Void

    @State private var mode: ScheduleViewMode = .all
    @State private var searchText = ""

    private var filteredHabits: [UIHabit] {
        guard !searchText.isEmpty else {
            return habits
        }

        return habits.filter { $0.displayTitle.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ScreenScaffold(title: L10n.t("schedule.title")) {
                Card {
                    Picker(L10n.t("schedule.mode"), selection: $mode) {
                        ForEach(ScheduleViewMode.allCases) { current in
                            Text(L10n.t(current.titleKey)).tag(current)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                switch mode {
                case .all:
                    allHabitsSection
                case .upcoming:
                    upcomingSection
                case .week:
                    placeholderSection(
                        title: L10n.t("schedule.week.placeholder.title"),
                        subtitle: L10n.t("schedule.week.placeholder.subtitle"),
                        actionTitle: L10n.t("schedule.open_week_placeholder"),
                        action: onOpenWeekPlaceholder
                    )
                case .month:
                    placeholderSection(
                        title: L10n.t("schedule.month.placeholder.title"),
                        subtitle: L10n.t("schedule.month.placeholder.subtitle"),
                        actionTitle: L10n.t("schedule.open_month_placeholder"),
                        action: onOpenMonthPlaceholder
                    )
                }
            } footer: {
                TextField(L10n.t("common.search"), text: $searchText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.tertiarySystemBackground))
                    )
            }
            .navigationBarTitleDisplayMode(.large)
            .sunnadSolidBars()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.done")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t("common.edit")) {}
                }
            }
        }
    }

    private var allHabitsSection: some View {
        Group {
            if filteredHabits.isEmpty {
                Card {
                    Text(L10n.t("schedule.empty"))
                        .foregroundStyle(.secondary)
                }
            } else {
                Card(contentPadding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(filteredHabits.enumerated()), id: \.element.id) { index, habit in
                            HabitRowView(habit: habit, onTap: { onSelectHabit(habit) })
                                .padding(.horizontal, 16)

                            if index < filteredHabits.count - 1 {
                                Divider().padding(.leading, 62)
                            }
                        }
                    }
                }
            }
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(0..<7, id: \.self) { offset in
                let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
                let dayHabits = habits.filter { $0.isScheduled(on: date) }

                SectionHeader(title: dayTitle(for: date, offset: offset))

                if dayHabits.isEmpty {
                    Card {
                        Text(L10n.t("schedule.none_for_day"))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Card(contentPadding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(dayHabits.enumerated()), id: \.element.id) { index, habit in
                                HabitRowView(habit: habit, onTap: { onSelectHabit(habit) })
                                    .padding(.horizontal, 16)

                                if index < dayHabits.count - 1 {
                                    Divider().padding(.leading, 62)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func placeholderSection(
        title: String,
        subtitle: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                SecondaryButton(title: actionTitle, action: action)
            }
        }
    }

    private func dayTitle(for date: Date, offset: Int) -> String {
        if offset == 0 {
            return L10n.t("schedule.today")
        }

        if offset == 1 {
            return L10n.t("schedule.tomorrow")
        }

        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}
