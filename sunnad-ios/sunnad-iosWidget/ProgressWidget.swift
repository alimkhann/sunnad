import SwiftUI
import WidgetKit

struct ProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "adat.progress", provider: SnapshotTimelineProvider()) { entry in
            ProgressEntryView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringResource("widgets.progress.name"))
        .description(LocalizedStringResource("widgets.progress.description"))
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

private struct ProgressEntryView: View {
    let entry: WidgetSnapshotEntry

    @Environment(\.widgetFamily) private var family

    private var snapshot: TodaySnapshot? { entry.snapshot }
    private var completed: Int { snapshot?.completedCount ?? 0 }
    private var total: Int { max(snapshot?.totalCount ?? 0, 1) }
    private var bestStreak: Int {
        snapshot?.habits.map(\.streak).max() ?? 0
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
        } else if (snapshot?.habits ?? []).isEmpty {
            Text(L10n.t("widgets.today.empty"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch family {
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("widgets.today.progress", "\(completed)", "\(snapshot?.totalCount ?? 0)"))
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if bestStreak > 0 {
                        Label("\(bestStreak)", systemImage: "flame")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                    ProgressView(value: Double(completed), total: Double(total))
                        .tint(WidgetTheme.primary)
                }
            default:
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .stroke(Color(.systemFill), lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: min(Double(completed) / Double(total), 1))
                            .stroke(WidgetTheme.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(completed)")
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                    }
                    if bestStreak > 0 {
                        Label("\(bestStreak)", systemImage: "flame")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.yellow)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
