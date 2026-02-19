import SwiftUI

struct TodayView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var showsCompleted = false

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

    private var incompleteHabits: [UIHabit] {
        habits.filter { !$0.completedToday }
    }

    private var completedHabits: [UIHabit] {
        habits.filter(\.completedToday)
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
            } else {
                Text(String(format: L10n.t("today.progress"), completedCount, habits.count))
                    .font(.body)
                    .foregroundStyle(.secondary)

                if incompleteHabits.isEmpty {
                    Card {
                        EmptyStateView(
                            symbol: "calendar",
                            title: L10n.t("today.all_done.title"),
                            message: L10n.t("today.all_done.subtitle"),
                            primaryTitle: L10n.t("today.all_done.open_schedule"),
                            primaryAction: onManage
                        )
                    }
                } else {
                    Card(contentPadding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(incompleteHabits.enumerated()), id: \.element.id) { index, habit in
                                HabitRowView(
                                    habit: habit,
                                    onTap: { onSelectHabit(habit) },
                                    onToggle: { onToggle(habit.id) }
                                )
                                .padding(.horizontal, 16)

                                if index < incompleteHabits.count - 1 {
                                    Divider().padding(.leading, 62)
                                }
                            }
                        }
                    }
                }

                if !completedHabits.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showsCompleted.toggle()
                        }
                    } label: {
                        HStack {
                            Text(L10n.t("today.completed.section"))
                                .font(.caption.weight(.semibold))
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: showsCompleted ? "chevron.down" : "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    if showsCompleted {
                        Card(contentPadding: 0) {
                            VStack(spacing: 0) {
                                ForEach(Array(completedHabits.enumerated()), id: \.element.id) { index, habit in
                                    HabitRowView(
                                        habit: habit,
                                        isDimmed: true,
                                        onTap: { onSelectHabit(habit) },
                                        onToggle: { onToggle(habit.id) }
                                    )
                                    .padding(.horizontal, 16)

                                    if index < completedHabits.count - 1 {
                                        Divider().padding(.leading, 62)
                                    }
                                }
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
                .accessibilityIdentifier("today.manage.button")

                Button(action: onAddHabit) {
                    Image(systemName: "plus")
                        .font(.headline)
                }
                .accessibilityLabel(L10n.t("today.add_habit"))
                .accessibilityIdentifier("today.add.button")
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
