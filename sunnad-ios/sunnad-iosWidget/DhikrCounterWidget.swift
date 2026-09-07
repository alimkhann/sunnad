import AppIntents
import SwiftUI
import WidgetKit

struct DhikrCounterConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("widgets.dhikr.name")
    static var description = IntentDescription(LocalizedStringResource("widgets.dhikr.description"))

    @Parameter(title: LocalizedStringResource("widgets.intents.param.habit"))
    var habit: WidgetDhikrEntity?
}

struct DhikrCounterWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "adat.dhikr.counter",
            intent: DhikrCounterConfigurationIntent.self,
            provider: ConfigurableSnapshotProvider(mapConfiguration: { intent in (nil, intent.habit, nil) })
        ) { entry in
            DhikrCounterEntryView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringResource("widgets.dhikr.name"))
        .description(LocalizedStringResource("widgets.dhikr.description"))
        .supportedFamilies([.systemSmall])
    }
}

private struct DhikrCounterEntryView: View {
    let entry: WidgetSnapshotEntry

    private var habit: HabitSnapshot? {
        if let configured = entry.configurationDhikr,
           let id = UUID(uuidString: configured.id) {
            return entry.snapshot?.habits.first { $0.id == id }
        }
        let dhikrHabits = (entry.snapshot?.habits ?? []).filter(\.isDhikr)
        return dhikrHabits.first { !$0.completedToday } ?? dhikrHabits.first
    }

    private var count: Int { habit?.dhikrCount ?? 0 }
    private var target: Int { max(habit?.targetCount ?? 1, 1) }

    var body: some View {
        content
            .containerBackground(for: .widget) {
                WidgetTheme.background
            }
    }

    @ViewBuilder
    private var content: some View {
        if WidgetSupport.isStale(entry.snapshot, date: entry.date) {
            StaleStateView()
        } else if let habit {
            incrementableHabit(habit)
        } else {
            Text(L10n.t("widgets.today.empty"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// The whole widget counts a dhikr via AppIntent — taps must never open the app.
    @ViewBuilder
    private func incrementableHabit(_ habit: HabitSnapshot) -> some View {
        Button(intent: IncrementDhikrIntent(habitID: habit.id.uuidString)) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color(.systemFill), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: min(Double(count) / Double(target), 1))
                        .stroke(WidgetTheme.primary, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(count)")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
                Text(habit.title)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
        .accessibilityLabel(L10n.t("widgets.intents.dhikr.title"))
    }
}
