import SwiftUI

struct TemplatesOnboardingView: View {
    @Binding var selectedIDs: Set<String>

    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

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
            HStack(spacing: 12) {
                CompactBackButton(action: onBack)

                Text(L10n.t("onboarding.templates.title"))
                    .font(.title.weight(.bold))

                Spacer(minLength: 0)

                Button(L10n.t("onboarding.welcome.skip"), action: onSkip)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(L10n.t("onboarding.templates.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(String(format: L10n.t("onboarding.templates.selection_count"), selectedIDs.count))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(selectedIDs.isEmpty ? .secondary : SunnadTheme.primary)
            }

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
                                .accessibilityIdentifier("onboarding.template.\(template.id)")
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
                .accessibilityIdentifier("onboarding.templates.continue.button")
            }
        }
    }

    private func toggle(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else if selectedIDs.count < 3 {
            selectedIDs.insert(id)
        }
    }
}
