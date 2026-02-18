import SwiftUI

struct TodayView: View {
    @Environment(\.colorScheme) private var colorScheme

    let habits: [UIHabit]
    let quote: UIQuote
    let onToggle: (UUID) -> Void
    let onSelectHabit: (UIHabit) -> Void
    let onManage: () -> Void
    let onAddHabit: () -> Void
    let onOpenQuote: () -> Void

    private var completedCount: Int {
        habits.filter(\.completedToday).count
    }

    private var allDone: Bool {
        !habits.isEmpty && habits.allSatisfy(\.completedToday)
    }

    var body: some View {
        ScreenScaffold(contentTopPadding: 8) {
            headerRow

            QuoteCardView(quote: quote, onTap: onOpenQuote)

            if habits.isEmpty {
                Card {
                    EmptyStateView(
                        symbol: "calendar.badge.exclamationmark",
                        title: L10n.t("today.empty.title"),
                        message: L10n.t("today.empty.subtitle"),
                        primaryTitle: L10n.t("today.add_habit"),
                        primaryAction: onAddHabit,
                        secondaryTitle: L10n.t("today.manage"),
                        secondaryAction: onManage
                    )
                }
            } else if allDone {
                Card {
                    EmptyStateView(
                        symbol: "checkmark.seal.fill",
                        title: L10n.t("today.all_done.title"),
                        message: L10n.t("today.all_done.subtitle"),
                        primaryTitle: L10n.t("today.quote_of_day"),
                        primaryAction: onOpenQuote
                    )
                }
            } else {
                Text(String(format: L10n.t("today.progress"), completedCount, habits.count))
                    .font(.body)
                    .foregroundStyle(.secondary)

                Card(contentPadding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                            HabitRowView(
                                habit: habit,
                                onTap: { onSelectHabit(habit) },
                                onToggle: { onToggle(habit.id) }
                            )
                            .padding(.horizontal, 16)

                            if index < habits.count - 1 {
                                Divider().padding(.leading, 62)
                            }
                        }
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sunnadSolidBars()
        .background(alignment: .top) {
            if colorScheme == .dark {
                Color.black
                    .frame(height: 132)
                    .ignoresSafeArea(edges: .top)
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(L10n.t("tab.today"))
                .font(.title.weight(.bold))

            Spacer()

            HStack(spacing: 8) {
                Button(action: onManage) {
                    Image(systemName: "calendar")
                        .font(.headline)
                }
                .accessibilityLabel(L10n.t("today.manage"))

                Button(action: onAddHabit) {
                    Image(systemName: "plus")
                        .font(.headline)
                }
                .accessibilityLabel(L10n.t("today.add_habit"))
            }
            .foregroundStyle(SunnadTheme.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(.tertiarySystemFill))
            )
        }
    }
}
