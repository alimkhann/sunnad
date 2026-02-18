import SwiftUI

struct TemplatesOnboardingView: View {
    @Binding var selectedIDs: Set<String>

    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var searchText = ""

    private var filteredTemplates: [HabitTemplate] {
        if searchText.isEmpty {
            return UIFixtures.templates
        }

        return UIFixtures.templates.filter {
            L10n.t($0.titleKey).localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ScreenScaffold(title: nil, titleDisplayMode: .large) {
            HStack {
                pillToolbarButton(title: L10n.t("common.back"), action: onBack)
                Spacer()
            }
            .padding(.top, 8)

            Text(L10n.t("onboarding.templates.title"))
                .font(.title.weight(.bold))

            ForEach(HabitCategory.allCases) { category in
                let sectionItems = filteredTemplates.filter { $0.category == category }
                if !sectionItems.isEmpty {
                    SectionHeader(title: L10n.t(category.titleKey))
                    Card(contentPadding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(sectionItems.enumerated()), id: \.element.id) { index, template in
                                SelectableRow(
                                    title: L10n.t(template.titleKey),
                                    iconSystemName: template.iconSystemName,
                                    isSelected: selectedIDs.contains(template.id),
                                    indicatorPlacement: .trailing,
                                    showsDivider: index < sectionItems.count - 1
                                ) {
                                    toggle(template.id)
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
                    title: L10n.t("common.continue"),
                    isEnabled: !selectedIDs.isEmpty,
                    action: onContinue
                )
            }
        }
    }

    private func toggle(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func pillToolbarButton(
        title: String,
        action: @escaping () -> Void,
        isEnabled: Bool = true
    ) -> some View {
        Button(title, action: action)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .foregroundStyle(isEnabled ? .primary : .secondary)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(.tertiarySystemFill))
            )
            .disabled(!isEnabled)
    }
}
