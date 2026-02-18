import SwiftUI

struct TodayView: View {
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
        ScreenScaffold {
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
                Card {
                    Text(String(format: L10n.t("today.progress"), completedCount, habits.count))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

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
        .navigationTitle(L10n.t("tab.today"))
        .navigationBarTitleDisplayMode(.large)
        .sunnadSolidBars()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(L10n.t("today.manage"), action: onManage)
                Button(action: onAddHabit) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(L10n.t("today.add_habit"))
            }
        }
    }
}
