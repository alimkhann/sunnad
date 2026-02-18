import SwiftUI

struct HabitRowView: View {
    let habit: UIHabit
    let showsChevron: Bool
    let onTap: () -> Void
    let onToggle: (() -> Void)?

    init(habit: UIHabit, showsChevron: Bool = true, onTap: @escaping () -> Void, onToggle: (() -> Void)? = nil) {
        self.habit = habit
        self.showsChevron = showsChevron
        self.onTap = onTap
        self.onToggle = onToggle
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: habit.iconSystemName)
                    .font(.headline)
                    .foregroundStyle(SunnadTheme.primary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color(.secondarySystemGroupedBackground)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.displayTitle)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    if habit.streak > 0 {
                        Text("\(habit.streak) \(L10n.t("today.day_streak"))")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }

                Spacer(minLength: 8)

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }

                if let onToggle {
                    Button(action: onToggle) {
                        Image(systemName: habit.completedToday ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(habit.completedToday ? SunnadTheme.primary : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("today.toggle_completion"))
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
