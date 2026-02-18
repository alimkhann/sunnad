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
    let onAddCustomHabit: (String, String, HabitCategory, HabitSchedule, Set<Int>, Date?) -> Void

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

    private let customIcons = [
        "sunrise.fill", "sun.max.fill", "moon.fill", "book.fill", "text.book.closed.fill", "figure.run",
        "heart.fill", "person.2.fill", "person.2.circle.fill", "house.fill", "face.smiling.fill", "building.columns.fill",
        "cup.and.saucer.fill", "fork.knife", "bed.double.fill", "character.book.closed.fill", "star.fill", "character.book.closed",
        "creditcard.fill", "hand.thumbsup.fill"
    ]

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

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(L10n.t("habit.add"))
                .navigationBarTitleDisplayMode(.inline)
                .sunnadSolidBars()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.t("common.cancel")) {
                            dismiss()
                        }
                    }

                    if step != .choice {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(L10n.t("common.back")) {
                                step = .choice
                            }
                        }
                    }

                    if step == .templates {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.t("common.add"), action: addSelectedTemplates)
                                .disabled(selectedTemplateIDs.isEmpty)
                        }
                    }

                    if step == .custom {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.t("common.add"), action: addCustomHabit)
                                .disabled(trimmedName.isEmpty)
                        }
                    }
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
        ScreenScaffold(title: nil, titleDisplayMode: .inline) {
            VStack(spacing: 16) {
                Spacer(minLength: 220)

                PrimaryButton(title: L10n.t("habit.add.templates")) {
                    step = .templates
                }

                SecondaryButton(title: L10n.t("habit.add.custom")) {
                    step = .custom
                }

                Spacer(minLength: 220)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var templatesStep: some View {
        ScreenScaffold(title: nil, titleDisplayMode: .inline) {
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
            TextField(L10n.t("common.search"), text: $searchText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.tertiarySystemBackground))
                )
        }
    }

    private var customStep: some View {
        ScreenScaffold(title: nil, titleDisplayMode: .inline) {
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
                HStack(spacing: 12) {
                    Image(systemName: customIcon)
                        .font(.title2)
                        .foregroundStyle(SunnadTheme.primary)
                        .frame(width: 36)

                    Text(L10n.t("habit.icon"))
                        .font(.title3.weight(.medium))

                    Spacer()
                }

                let columns = [
                    GridItem(.adaptive(minimum: 46), spacing: 12)
                ]

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(customIcons, id: \.self) { icon in
                        Button {
                            customIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.title3)
                                .foregroundStyle(customIcon == icon ? .white : SunnadTheme.primary)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(customIcon == icon ? SunnadTheme.primary : Color(.tertiarySystemBackground))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 8)
            }

            SectionHeader(title: L10n.t("habit.schedule"))
            Card {
                Picker(L10n.t("habit.schedule"), selection: $customSchedule) {
                    ForEach(HabitSchedule.allCases) { schedule in
                        Text(L10n.t(schedule.titleKey)).tag(schedule)
                    }
                }
                .pickerStyle(.segmented)

                if customSchedule == .weekly {
                    WeekdayPickerRow(selectedDays: $customWeekdays)
                        .padding(.top, 12)
                }
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
        }
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
            reminderEnabled ? reminderTime : nil
        )
        dismiss()
    }
}
