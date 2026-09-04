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

    @Binding private var persistedHabit: UIHabit
    @State private var habit: UIHabit

    let user: UIUserState
    let groups: [UIGroup]
    let lastSevenCompletionMarksOverride: [Bool]?
    let onDelete: (UUID) -> Void
    let onUpdateHabitSharing: (UUID, Set<UUID>) -> Void
    let onDhikrIncremented: (Bool) -> Void

    @State private var mode: HabitDetailMode = .details
    @State private var isSymbolPickerPresented = false
    @State private var showsDeleteConfirmation = false
    @State private var didApplyDebugMode = false
    @State private var sharedGroupIDs: Set<UUID> = []
    @State private var originalSharedGroupIDs: Set<UUID> = []
    @State private var customCategoryEnabled = false
    @State private var customCategoryDraft = ""

    init(
        habit: Binding<UIHabit>,
        user: UIUserState,
        groups: [UIGroup],
        lastSevenCompletionMarksOverride: [Bool]?,
        onDelete: @escaping (UUID) -> Void,
        onUpdateHabitSharing: @escaping (UUID, Set<UUID>) -> Void,
        onDhikrIncremented: @escaping (Bool) -> Void
    ) {
        _persistedHabit = habit
        _habit = State(initialValue: habit.wrappedValue)
        self.user = user
        self.groups = groups
        self.lastSevenCompletionMarksOverride = lastSevenCompletionMarksOverride
        self.onDelete = onDelete
        self.onUpdateHabitSharing = onUpdateHabitSharing
        self.onDhikrIncremented = onDhikrIncremented
    }

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
                        DhikrCounterView(
                            count: $habit.dhikrCount,
                            target: $habit.dhikrTarget,
                            phraseKey: $habit.dhikrPhraseKey,
                            customPhrase: $habit.dhikrCustomPhrase,
                            onIncremented: onDhikrIncremented
                        )
                    }
                } else {
                    detailsContent
                }
            } footer: {
                PrimaryButton(title: L10n.t("habit.save_changes")) {
                    saveDraft()
                }
                .accessibilityIdentifier("habit.save.button")
                .disabled(!isDraftValid)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sunnadSolidBars()
            .onAppear(perform: applyDebugModeIfNeeded)
            .onAppear(perform: syncSharedGroups)
            .onAppear(perform: syncCustomCategoryDraft)
            .onChange(of: groups) {
                syncSharedGroups()
            }
            .onChange(of: habit.dhikrCount) { _, newValue in
                guard newValue != persistedHabit.dhikrCount else { return }
                var immediateHabit = persistedHabit
                immediateHabit.dhikrCount = newValue
                immediateHabit.completedToday = newValue >= max(immediateHabit.dhikrTarget, 1)
                persistedHabit = immediateHabit
            }
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
                    .frame(width: 44, height: 44)
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
                    .frame(width: 44, height: 44)
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
                VStack(spacing: 0) {
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

                    Divider().padding(.leading, 16)

                    Toggle(L10n.t("habit.category_custom_option"), isOn: $customCategoryEnabled)
                        .padding(16)
                        .onChange(of: customCategoryEnabled) { _, enabled in
                            if enabled {
                                let current = (habit.categoryCustom ?? customCategoryDraft).trimmingCharacters(in: .whitespacesAndNewlines)
                                customCategoryDraft = current
                                habit.categoryCustom = current.isEmpty ? "" : current
                            } else {
                                habit.categoryCustom = nil
                            }
                        }

                    if customCategoryEnabled {
                        Divider().padding(.leading, 16)
                        TextField(L10n.t("habit.category_custom_placeholder"), text: $customCategoryDraft)
                            .textFieldStyle(.plain)
                            .padding(16)
                            .onChange(of: customCategoryDraft) { _, newValue in
                                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                habit.categoryCustom = trimmed.isEmpty ? nil : trimmed
                            }
                    }
                }
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
                        title: L10n.t(UIHabitSchedule.daily.titleKey),
                        selected: habit.schedule == .daily
                    ) {
                        habit.schedule = .daily
                    }

                    Divider().padding(.leading, 16)

                    scheduleChoiceRow(
                        title: L10n.t(UIHabitSchedule.weekly.titleKey),
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
                Card(contentPadding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                            Toggle(isOn: Binding(
                                get: { sharedGroupIDs.contains(group.id) },
                                set: { isOn in
                                    if isOn {
                                        sharedGroupIDs.insert(group.id)
                                    } else {
                                        sharedGroupIDs.remove(group.id)
                                    }
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.name)
                                        .font(.body.weight(.medium))
                                    Text(String(format: L10n.t("groups.members_count"), group.members.count))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)

                            if index < groups.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
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
        let calendar = Calendar.current
        let symbols = calendar.shortWeekdaySymbols
        guard symbols.count == 7 else {
            return ["M", "T", "W", "T", "F", "S", "S"]
        }

        let today = Date()
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset - 6, to: today)!
            let weekday = calendar.component(.weekday, from: date) // 1=Sun..7=Sat
            return String(symbols[weekday - 1].prefix(1))
        }
    }

    private var lastSevenCompletionMarks: [Bool] {
        if let lastSevenCompletionMarksOverride, lastSevenCompletionMarksOverride.count == 7 {
            return lastSevenCompletionMarksOverride
        }

        // Days before today that were completed (based on streak minus today's contribution)
        let priorStreak = habit.completedToday ? max(habit.streak - 1, 0) : habit.streak
        let priorDays = min(priorStreak, 6)
        // First 6 slots represent the 6 days before today; last slot is today
        var marks = Array(repeating: false, count: 6 - priorDays)
            + Array(repeating: true, count: priorDays)
        marks.append(habit.completedToday)
        return marks
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

    private func syncCustomCategoryDraft() {
        let normalized = habit.categoryCustom?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        customCategoryEnabled = !normalized.isEmpty
        customCategoryDraft = normalized
    }

    private func syncSharedGroups() {
        let resolved = Set(
            groups
                .filter { $0.sharedHabitIDs.contains(habit.id) }
                .map(\.id)
        )
        sharedGroupIDs = resolved
        originalSharedGroupIDs = resolved
    }

    private func saveDraft() {
        if habit.isDhikr {
            let customPhrase = habit.dhikrCustomPhrase?.trimmingCharacters(in: .whitespacesAndNewlines)
            if customPhrase?.isEmpty == false {
                habit.dhikrCustomPhrase = String(customPhrase!.prefix(80))
                habit.dhikrPhraseKey = nil
            } else {
                habit.dhikrCustomPhrase = nil
                habit.dhikrPhraseKey = habit.dhikrPhraseKey ?? UIHabit.defaultDhikrPhraseKey
            }
            habit.dhikrTarget = min(max(habit.dhikrTarget, 1), 999_999)
        }

        persistedHabit = habit
        if sharedGroupIDs != originalSharedGroupIDs {
            onUpdateHabitSharing(habit.id, sharedGroupIDs)
        }
        dismiss()
    }

    private var isDraftValid: Bool {
        guard habit.isDhikr else { return true }
        if let customPhrase = habit.dhikrCustomPhrase {
            return !customPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return habit.dhikrPhraseKey != nil
    }
}
