import AppIntents
import SwiftUI
import WidgetKit

struct TodayChecklistWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "adat.today.checklist", provider: SnapshotTimelineProvider()) { entry in
            TodayChecklistEntryView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringResource("widgets.checklist.name"))
        .description(LocalizedStringResource("widgets.checklist.description"))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct TodayChecklistEntryView: View {
    let entry: WidgetSnapshotEntry

    @Environment(\.widgetFamily) private var family

    private var habits: [HabitSnapshot] {
        entry.snapshot?.habits ?? []
    }

    private var visibleHabits: [HabitSnapshot] {
        Array(habits.prefix(family == .systemLarge ? 8 : 5))
    }

    var body: some View {
        content
            .widgetURL(URL(string: "adat://today"))
            .containerBackground(for: .widget) {
                WidgetTheme.background
            }
    }

    @ViewBuilder
    private var content: some View {
        if WidgetSupport.isStale(entry.snapshot, date: entry.date) {
            StaleStateView()
        } else if habits.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(visibleHabits, id: \.id) { habit in
                    WidgetHabitRowView(habit: habit)
                    if habit.id != visibleHabits.last?.id {
                        Divider()
                    }
                }
                if habits.count > visibleHabits.count {
                    Text(L10n.t("widgets.more", habits.count - visibleHabits.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(L10n.t("widgets.today.progress", "\(entry.snapshot?.completedCount ?? 0)", "\(entry.snapshot?.totalCount ?? 0)"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(L10n.t("widgets.today.empty"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WidgetHabitRowView: View {
    let habit: HabitSnapshot

    var body: some View {
        HStack(spacing: 10) {
            Button(intent: ToggleHabitIntent(habitID: habit.id.uuidString)) {
                Image(systemName: habit.completedToday ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(habit.completedToday ? WidgetTheme.primary : .secondary)
            }
            .buttonStyle(.plain)

            Link(destination: URL(string: "adat://today")!) {
                HStack(spacing: 6) {
                    Image(systemName: habit.icon)
                        .font(.footnote)
                        .foregroundStyle(WidgetTheme.primary)

                    Text(habit.title)
                        .font(.footnote)
                        .lineLimit(1)

                    if habit.streak > 0 {
                        Label("\(habit.streak)", systemImage: "flame")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct StaleStateView: View {
    var deepLink: URL?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(L10n.t("widgets.stale"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(deepLink ?? URL(string: "adat://today"))
    }
}
