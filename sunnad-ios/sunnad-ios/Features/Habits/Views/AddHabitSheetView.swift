import SwiftUI

private enum AddHabitStep {
    case choice
    case templates
    case custom
}

struct AddHabitSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let existingHabits: [UIHabit]
    let onAddTemplates: ([HabitTemplate]) -> Void
    let onAddCustomHabit: (String, String, HabitCategory, HabitSchedule, Set<Int>, Date?, Bool) -> Void

    @State private var step: AddHabitStep = .choice
    @State private var selectedTemplateIDs: Set<String> = []
    @State private var searchText = ""

    @State private var customName = ""
    @State private var customIcon = "star.fill"
    @State private var customCategory: HabitCategory = .spiritual
    @State private var customSchedule: HabitSchedule = .daily
    @State private var customWeekdays: Set<Int> = Set(0...6)
    @State private var reminderEnabled = false
    @State private var reminderTime = Date()
    @State private var customHasDhikrCounter = false
    @State private var isSymbolPickerPresented = false
    @State private var didApplyDebugOverrides = false

    private var availableTemplates: [HabitTemplate] {
        let existingKeys = Set(existingHabits.compactMap(\.templateTitleKey))
        let base = UIFixtures.templates.filter { !existingKeys.contains($0.titleKey) }

        guard !searchText.isEmpty else {
            return base
        }

        return base.filter { L10n.t($0.titleKey).localizedCaseInsensitiveContains(searchText) }
    }

    private var trimmedName: String {
        customName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var detents: Set<PresentationDetent> {
        switch step {
        case .choice:
            return [.fraction(0.42)]
        case .templates, .custom:
            return [.large]
        }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(L10n.t("habit.add"))
                .navigationBarTitleDisplayMode(.inline)
                .sunnadSolidBars()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if step == .choice {
                            EmptyView()
                        } else {
                            Button(L10n.t("common.back")) {
                                step = .choice
                            }
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel(L10n.t("common.cancel"))
                    }
                }
                .presentationDetents(detents)
                .presentationDragIndicator(step == .choice ? .hidden : .visible)
                .onAppear(perform: applyDebugOverridesIfNeeded)
                .sheet(isPresented: $isSymbolPickerPresented) {
                    SFSymbolPickerSheetView(selectedSymbol: $customIcon)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .choice:
            choiceStep
        case .templates:
            templatesStep
        case .custom:
            customStep
        }
    }

    private var choiceStep: some View {
        ScreenScaffold(title: nil, titleDisplayMode: .inline, contentTopPadding: 8) {
            VStack(spacing: 16) {
                Spacer(minLength: 12)

                PrimaryButton(title: L10n.t("habit.add.templates")) {
                    step = .templates
                }

                SecondaryButton(title: L10n.t("habit.add.custom")) {
                    step = .custom
                }

                Spacer(minLength: 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }
    }

    private var templatesStep: some View {
        ScreenScaffold(title: nil, titleDisplayMode: .inline, contentTopPadding: 8) {
            ForEach(HabitCategory.allCases) { category in
                let items = availableTemplates.filter { $0.category == category }
                if !items.isEmpty {
                    SectionHeader(title: L10n.t(category.titleKey))

                    Card(contentPadding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, template in
                                SelectableRow(
                                    title: L10n.t(template.titleKey),
                                    iconSystemName: template.iconSystemName,
                                    isSelected: selectedTemplateIDs.contains(template.id),
                                    indicatorPlacement: .trailing,
                                    showsDivider: index < items.count - 1
                                ) {
                                    toggleTemplate(template.id)
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
        } footer: {
            VStack(spacing: 12) {
                TextField(L10n.t("common.search"), text: $searchText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.tertiarySystemBackground))
                    )

                PrimaryButton(
                    title: L10n.t("common.add"),
                    isEnabled: !selectedTemplateIDs.isEmpty,
                    action: addSelectedTemplates
                )
            }
        }
    }

    private var customStep: some View {
        ScreenScaffold(title: nil, titleDisplayMode: .inline, contentTopPadding: 8) {
            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.t("habit.name"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField(L10n.t("habit.custom.name_placeholder"), text: $customName)
                            .textFieldStyle(.plain)
                    }
                    .padding(16)

                    Divider().padding(.leading, 16)

                    HStack {
                        Text(L10n.t("habit.category"))
                            .font(.body.weight(.medium))

                        Spacer()

                        Picker(L10n.t("habit.category"), selection: $customCategory) {
                            ForEach(HabitCategory.allCases) { category in
                                Text(L10n.t(category.titleKey)).tag(category)
                            }
                        }
                        .labelsHidden()
                    }
                    .padding(16)
                }
            }

            SectionHeader(title: L10n.t("habit.icon"))
            Card {
                Button {
                    isSymbolPickerPresented = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: customIcon)
                            .font(.headline)
                            .foregroundStyle(SunnadTheme.primary)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color(.secondarySystemGroupedBackground)))

                        Text(customIcon)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }

            SectionHeader(title: L10n.t("habit.schedule"))
            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    scheduleChoiceRow(title: L10n.t(HabitSchedule.daily.titleKey), selected: customSchedule == .daily) {
                        customSchedule = .daily
                    }

                    Divider().padding(.leading, 16)

                    scheduleChoiceRow(title: L10n.t(HabitSchedule.weekly.titleKey), selected: customSchedule == .weekly) {
                        customSchedule = .weekly
                    }

                    if customSchedule == .weekly {
                        Divider().padding(.leading, 16)
                        WeekdayPickerRow(selectedDays: $customWeekdays)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                }
            }

            SectionHeader(title: L10n.t("habit.counter"))
            Card {
                Toggle(L10n.t("habit.counter"), isOn: $customHasDhikrCounter)
            }

            SectionHeader(title: L10n.t("habit.reminder"))
            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    ReminderToggleRow(title: L10n.t("habit.reminder"), isOn: $reminderEnabled)
                        .padding(16)

                    if reminderEnabled {
                        Divider().padding(.leading, 16)
                        DatePicker(
                            L10n.t("habit.reminder_time"),
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .padding(16)
                    }
                }
            }
        } footer: {
            PrimaryButton(
                title: L10n.t("common.add"),
                isEnabled: !trimmedName.isEmpty,
                action: addCustomHabit
            )
        }
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

    private func toggleTemplate(_ id: String) {
        if selectedTemplateIDs.contains(id) {
            selectedTemplateIDs.remove(id)
        } else {
            selectedTemplateIDs.insert(id)
        }
    }

    private func addSelectedTemplates() {
        let selected = UIFixtures.templates.filter { selectedTemplateIDs.contains($0.id) }
        onAddTemplates(selected)
        dismiss()
    }

    private func addCustomHabit() {
        onAddCustomHabit(
            trimmedName,
            customIcon,
            customCategory,
            customSchedule,
            customWeekdays,
            reminderEnabled ? reminderTime : nil,
            customHasDhikrCounter
        )
        dismiss()
    }

    private func applyDebugOverridesIfNeeded() {
        #if DEBUG
        guard !didApplyDebugOverrides else {
            return
        }
        didApplyDebugOverrides = true

        guard let rawStep = ProcessInfo.processInfo.environment["SUNNAD_DEBUG_ADD_HABIT_STEP"]?.lowercased() else {
            return
        }

        switch rawStep {
        case "choice":
            step = .choice
        case "templates":
            step = .templates
        case "custom":
            step = .custom
        default:
            break
        }
        #endif
    }
}
