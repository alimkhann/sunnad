import SwiftUI

struct ScheduleScreenView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Binding var habits: [UIHabit]

    let onSelectHabit: (UIHabit) -> Void

    @State private var mode: ScheduleViewMode = .all
    @State private var searchText = ""
    @State private var isEditing = false
    @State private var didApplyDebugMode = false

    private var filteredHabits: [UIHabit] {
        guard !searchText.isEmpty else {
            return habits
        }

        return habits.filter { $0.displayTitle.localizedCaseInsensitiveContains(searchText) }
    }

    private var showsBottomSearchOnCurrentOS: Bool {
        if #available(iOS 26.0, *) {
            return true
        }

        return false
    }

    var body: some View {
        NavigationStack {
            ScreenScaffold(contentTopPadding: 8) {
                headerRow

                Text(L10n.t("schedule.title"))
                    .font(.title.weight(.bold))

                Picker(L10n.t("schedule.mode"), selection: $mode) {
                    ForEach(ScheduleViewMode.allCases) { current in
                        Text(L10n.t(current.titleKey)).tag(current)
                    }
                }
                .pickerStyle(.segmented)

                if mode == .all && !showsBottomSearchOnCurrentOS {
                    searchField
                }

                switch mode {
                case .all:
                    allHabitsSection
                case .upcoming:
                    upcomingSection
                case .week:
                    weekSection
                case .month:
                    monthSection
                }
            } footer: {
                if mode == .all && showsBottomSearchOnCurrentOS {
                    searchField
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sunnadSolidBars()
            .onAppear(perform: applyDebugModeIfNeeded)
            .onChange(of: mode) { _, newMode in
                if newMode != .all {
                    isEditing = false
                }
            }
            .background(alignment: .top) {
                if colorScheme == .dark {
                    Color.black
                        .frame(height: 128)
                        .ignoresSafeArea(edges: .top)
                }
            }
        }
    }

    private var headerRow: some View {
        HStack {
            CompactBackButton {
                dismiss()
            }

            Spacer()

            if mode == .all {
                Button(isEditing ? L10n.t("common.done") : L10n.t("common.reorder")) {
                    isEditing.toggle()
                }
                .font(.headline)
                .foregroundStyle(SunnadTheme.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                )
            }
        }
    }

    private var allHabitsSection: some View {
        SwiftUI.Group {
            if filteredHabits.isEmpty {
                Card {
                    Text(L10n.t("schedule.empty"))
                        .foregroundStyle(.secondary)
                }
            } else {
                Card(contentPadding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(filteredHabits.enumerated()), id: \.element.id) { index, habit in
                            HStack(spacing: 8) {
                                if isEditing {
                                    Image(systemName: "line.3.horizontal")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)
                                }

                                HabitRowView(
                                    habit: habit,
                                    showsChevron: !isEditing,
                                    onTap: { onSelectHabit(habit) }
                                )
                            }
                            .padding(.horizontal, 16)

                            if index < filteredHabits.count - 1 {
                                Divider().padding(.leading, isEditing ? 82 : 62)
                            }
                        }
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(L10n.t("common.search"), text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.tertiarySystemBackground))
        )
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
                                HabitRowView(habit: habit, showsStreak: false, onTap: { onSelectHabit(habit) })
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

    private var weekSection: some View {
        let labels = mondayWeekdaySymbols
        return Card(contentPadding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    HStack {
                        Text(label)
                            .font(.title3.weight(.semibold))
                        Spacer()
                        Text("\(habitsForWeekday(index).count)")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    if index < labels.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
        }
    }

    private var monthSection: some View {
        let calendar = Calendar.current
        let today = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        let dayRange = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<2
        let firstWeekdayOffset = max(0, calendar.component(.weekday, from: monthStart) - 1)
        let weekdayLabels = calendar.shortStandaloneWeekdaySymbols

        return VStack(alignment: .leading, spacing: 12) {
            Card {
                Text(monthStart.formatted(.dateTime.month(.wide).year()))
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            HStack(spacing: 0) {
                ForEach(weekdayLabels, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 6)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Color.clear
                        .frame(height: 52)
                }

                ForEach(Array(dayRange), id: \.self) { day in
                    let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) ?? today
                    let count = habits.filter { $0.isScheduled(on: date) }.count
                    let isToday = calendar.isDate(date, inSameDayAs: today)

                    VStack(spacing: 2) {
                        Text("\(day)")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(isToday ? .white : .primary)
                        Text("\(count)")
                            .font(.caption2)
                            .foregroundStyle(isToday ? .white.opacity(0.88) : .secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isToday ? SunnadTheme.primary : SunnadTheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(SunnadTheme.border, lineWidth: isToday ? 0 : 0.5)
                    )
                }
            }
        }
    }

    private var mondayWeekdaySymbols: [String] {
        let symbols = Calendar.current.weekdaySymbols
        guard symbols.count == 7 else {
            return symbols
        }

        return Array(symbols[1...6]) + [symbols[0]]
    }

    private func habitsForWeekday(_ weekdayIndex: Int) -> [UIHabit] {
        habits.filter { habit in
            switch habit.schedule {
            case .daily:
                return true
            case .weekly:
                return habit.weekdays.contains(weekdayIndex)
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

    private func applyDebugModeIfNeeded() {
        #if DEBUG
        guard !didApplyDebugMode else {
            return
        }
        didApplyDebugMode = true

        guard let rawMode = ProcessInfo.processInfo.environment["SUNNAD_DEBUG_SCHEDULE_MODE"]?.lowercased() else {
            return
        }

        switch rawMode {
        case "all":
            mode = .all
        case "upcoming":
            mode = .upcoming
        case "week":
            mode = .week
        case "month":
            mode = .month
        default:
            break
        }
        #endif
    }
}
