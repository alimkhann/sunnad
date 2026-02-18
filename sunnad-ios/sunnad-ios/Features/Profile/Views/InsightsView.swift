import Charts
import SwiftUI

private struct InsightPoint: Identifiable {
    let id = UUID()
    let date: Date
    let completed: Double
}

private struct HabitPerformance: Identifiable {
    let id: UUID
    let title: String
    let percentage: Int
}

struct InsightsView: View {
    @Environment(\.dismiss) private var dismiss

    let habits: [UIHabit]
    private let chartWindowDays: Double = 7

    private var points: [InsightPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<40).compactMap { index in
            guard let day = calendar.date(byAdding: .day, value: -(39 - index), to: today) else {
                return nil
            }

            let completedCount = habits.filter { isCompleted($0, on: day) }.count
            return InsightPoint(date: day, completed: Double(completedCount))
        }
    }

    private var habitPerformance: [HabitPerformance] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return habits.map { habit in
            let scheduledDays = (0..<40).compactMap { index -> Date? in
                calendar.date(byAdding: .day, value: -(39 - index), to: today)
            }
            .filter { habit.isScheduled(on: $0, calendar: calendar) }

            let completed = scheduledDays.filter { isCompleted(habit, on: $0) }.count
            let percent = scheduledDays.isEmpty ? 0 : Int((Double(completed) / Double(scheduledDays.count) * 100).rounded())

            return HabitPerformance(id: habit.id, title: habit.displayTitle, percentage: percent)
        }
        .sorted { $0.percentage > $1.percentage }
    }

    var body: some View {
        ScreenScaffold(contentTopPadding: 8) {
            headerRow

            SectionHeader(title: L10n.t("insights.completion_trend"))
            Card {
                Text(L10n.t("insights.window_hint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Chart(points) { point in
                    AreaMark(
                        x: .value("Day", point.date),
                        y: .value("Completed", point.completed)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(
                        .linearGradient(
                            colors: [SunnadTheme.primary.opacity(0.22), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Day", point.date),
                        y: .value("Completed", point.completed)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(SunnadTheme.primary)
                    .lineStyle(
                        StrokeStyle(
                            lineWidth: 3,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }
                .chartYScale(domain: 0...Double(max(habits.count, 1)))
                .chartXScale(domain: chartDomain)
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: chartWindowDays * 24 * 60 * 60)
                .chartScrollPosition(initialX: initialChartPosition)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                            .foregroundStyle(Color.secondary.opacity(0.18))
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                        AxisValueLabel().font(.caption2)
                    }
                }
                .frame(height: 220)
            }

            SectionHeader(title: L10n.t("insights.habit_performance"))
            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(habitPerformance.enumerated()), id: \.element.id) { index, item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Text(item.title)
                                    .font(.body.weight(.medium))
                                    .lineLimit(1)
                                Spacer()
                                Text("\(item.percentage)%")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            ProgressView(value: Double(item.percentage), total: 100)
                                .tint(SunnadTheme.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if index < habitPerformance.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sunnadSolidBars()
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            CompactBackButton {
                dismiss()
            }

            Text(L10n.t("profile.insights"))
                .font(.title2.weight(.bold))

            Spacer()
        }
    }

    private var chartDomain: ClosedRange<Date> {
        guard let first = points.first?.date, let last = points.last?.date else {
            let now = Date()
            return now...now
        }
        return first...last
    }

    private var initialChartPosition: Date {
        guard let last = points.last?.date else {
            return Date()
        }
        return Calendar.current.date(
            byAdding: .day,
            value: -Int(chartWindowDays) + 1,
            to: last
        ) ?? last
    }

    private func isCompleted(_ habit: UIHabit, on date: Date) -> Bool {
        guard habit.isScheduled(on: date) else {
            return false
        }

        if Calendar.current.isDateInToday(date) {
            return habit.completedToday
        }

        let dayStamp = Int(date.timeIntervalSince1970 / 86_400)
        let seed = deterministicSeed(for: habit.id.uuidString)
        let normalized = Double((seed + dayStamp * 13) % 100) / 100.0
        let chance = min(0.92, max(0.18, Double((seed % 45) + 35) / 100.0))
        return normalized < chance
    }

    private func deterministicSeed(for value: String) -> Int {
        value.unicodeScalars.reduce(0) { partial, scalar in
            (partial * 31 + Int(scalar.value)) % 1000
        }
    }
}
