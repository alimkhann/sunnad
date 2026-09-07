import AppIntents
import SwiftUI
import WidgetKit

struct QuickToggleConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("widgets.quicktoggle.name")
    static var description = IntentDescription(LocalizedStringResource("widgets.quicktoggle.description"))

    @Parameter(title: LocalizedStringResource("widgets.intents.param.habit"))
    var habit: WidgetHabitEntity?
}

struct QuickToggleWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "adat.quicktoggle",
            intent: QuickToggleConfigurationIntent.self,
            provider: ConfigurableSnapshotProvider(mapConfiguration: { intent in (intent.habit, nil, nil) })
        ) { entry in
            QuickToggleEntryView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringResource("widgets.quicktoggle.name"))
        .description(LocalizedStringResource("widgets.quicktoggle.description"))
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

private struct QuickToggleEntryView: View {
    let entry: WidgetSnapshotEntry

    @Environment(\.widgetFamily) private var family

    private var habit: HabitSnapshot? {
        if let configured = entry.configurationHabit,
           let id = UUID(uuidString: configured.id) {
            return entry.snapshot?.habits.first { $0.id == id }
        }
        return defaultHabit
    }

    /// Default habit = first uncompleted today, then the first habit.
    private var defaultHabit: HabitSnapshot? {
        let habits = entry.snapshot?.habits ?? []
        return habits.first { !$0.completedToday } ?? habits.first
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
            staleContent
        } else if let habit {
            toggleableHabit(habit)
        } else {
            Text(L10n.t("widgets.today.empty"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// The whole widget toggles the habit in place via AppIntent — no app open.
    @ViewBuilder
    private func toggleableHabit(_ habit: HabitSnapshot) -> some View {
        Button(intent: ToggleHabitIntent(habitID: habit.id.uuidString)) {
            switch family {
            case .accessoryCircular:
                VStack(spacing: 2) {
                    Image(systemName: habit.completedToday ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(habit.completedToday ? WidgetTheme.primary : .white)
                    Text(habit.title)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            default:
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: habit.icon)
                        .font(.headline)
                        .foregroundStyle(WidgetTheme.primary)
                    Spacer(minLength: 0)
                    Text(habit.title)
                        .font(.footnote.weight(.medium))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(L10n.t("widgets.today.progress", "\(entry.snapshot?.completedCount ?? 0)", "\(entry.snapshot?.totalCount ?? 0)"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
        .accessibilityLabel(habit.completedToday
            ? L10n.t("widgets.intents.toggle.undone")
            : L10n.t("widgets.intents.toggle.title"))
    }

    private var staleContent: some View {
        Image(systemName: "clock.arrow.circlepath")
            .font(.title3)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
