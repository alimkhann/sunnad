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
    @State private var isSymbolPickerPresented = false
    @State private var showsDeleteConfirmation = false
    @State private var didApplyDebugMode = false

    var body: some View {
        NavigationStack {
            ScreenScaffold(contentTopPadding: 8) {
                topBar

                if habit.isDhikr {
                    Picker(L10n.t("habit.mode"), selection: $mode) {
                        ForEach(HabitDetailMode.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if mode == .counter, habit.isDhikr {
                    Card {
                        DhikrCounterView(count: $habit.dhikrCount, target: $habit.dhikrTarget)
                    }
                } else {
                    detailsContent
                }
            } footer: {
                if mode == .details || !habit.isDhikr {
                    PrimaryButton(title: L10n.t("habit.save_changes")) {
                        dismiss()
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sunnadSolidBars()
            .onAppear(perform: applyDebugModeIfNeeded)
            .sheet(isPresented: $isSymbolPickerPresented) {
                SFSymbolPickerSheetView(selectedSymbol: $habit.iconSystemName)
            }
            .confirmationDialog(
                L10n.t("habit.delete_confirm.title"),
                isPresented: $showsDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.t("common.delete"), role: .destructive) {
                    onDelete(habit.id)
                    dismiss()
                }
                Button(L10n.t("common.cancel"), role: .cancel) {}
            } message: {
                Text(L10n.t("habit.delete_confirm.message"))
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                showsDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.headline)
                    .foregroundStyle(.red)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color(.tertiarySystemFill)))
            }
            .accessibilityLabel(L10n.t("common.delete"))

            Spacer(minLength: 10)

            Text(habit.displayTitle)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 10)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color(.tertiarySystemFill)))
            }
            .accessibilityLabel(L10n.t("common.cancel"))
        }
    }

    private var detailsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: L10n.t("habit.last_7_days"))
            last7DaysCard

            SectionHeader(title: L10n.t("habit.name"))
            Card {
                TextField(L10n.t("habit.name_placeholder"), text: Binding(
                    get: { habit.customTitle ?? habit.displayTitle },
                    set: { habit.customTitle = $0 }
                ))
                .textFieldStyle(.plain)
                .padding(.vertical, 6)
            }

            SectionHeader(title: L10n.t("habit.category"))
            Card(contentPadding: 0) {
                HStack {
                    Text(L10n.t("habit.category"))
                        .font(.body.weight(.medium))

                    Spacer()

                    Picker(L10n.t("habit.category"), selection: $habit.category) {
                        ForEach(HabitCategory.allCases) { category in
                            Text(L10n.t(category.titleKey)).tag(category)
                        }
                    }
                    .labelsHidden()
                }
                .padding(16)
            }

            SectionHeader(title: L10n.t("habit.icon"))
            Card {
                Button {
                    isSymbolPickerPresented = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: habit.iconSystemName)
                            .font(.headline)
                            .foregroundStyle(SunnadTheme.primary)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color(.secondarySystemGroupedBackground)))

                        Text(habit.iconSystemName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            SectionHeader(title: L10n.t("habit.schedule"))
            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    scheduleChoiceRow(
                        title: L10n.t(HabitSchedule.daily.titleKey),
                        selected: habit.schedule == .daily
                    ) {
                        habit.schedule = .daily
                    }

                    Divider().padding(.leading, 16)

                    scheduleChoiceRow(
                        title: L10n.t(HabitSchedule.weekly.titleKey),
                        selected: habit.schedule == .weekly
                    ) {
                        habit.schedule = .weekly
                    }

                    if habit.schedule == .weekly {
                        Divider().padding(.leading, 16)
                        WeekdayPickerRow(selectedDays: $habit.weekdays)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
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

    private var last7DaysCard: some View {
        let days = lastSevenDaySymbols
        let marks = lastSevenCompletionMarks

        return Card {
            HStack(spacing: 8) {
                ForEach(0..<days.count, id: \.self) { index in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(marks[index] ? SunnadTheme.primary : Color(.tertiarySystemFill))
                            .frame(width: 38, height: 38)
                            .overlay {
                                if marks[index] {
                                    Image(systemName: "checkmark")
                                        .font(.footnote.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }

                        Text(days[index])
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var lastSevenDaySymbols: [String] {
        let symbols = Calendar.current.shortWeekdaySymbols
        guard symbols.count == 7 else {
            return ["M", "T", "W", "T", "F", "S", "S"]
        }

        let mondayFirst = Array(symbols[1...6]) + [symbols[0]]
        return mondayFirst.map { String($0.prefix(1)) }
    }

    private var lastSevenCompletionMarks: [Bool] {
        let completed = min(max(habit.streak, 0), 7)
        let start = max(0, 7 - completed)
        return (0..<7).map { $0 >= start }
    }

    private func scheduleChoiceRow(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(SunnadTheme.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func applyDebugModeIfNeeded() {
        #if DEBUG
        guard !didApplyDebugMode else {
            return
        }
        didApplyDebugMode = true

        guard habit.isDhikr,
              let rawMode = ProcessInfo.processInfo.environment["SUNNAD_DEBUG_HABIT_DETAIL_MODE"]?.lowercased() else {
            return
        }

        switch rawMode {
        case "details":
            mode = .details
        case "counter":
            mode = .counter
        default:
            break
        }
        #endif
    }
}
