import Charts
import SwiftUI

private struct InsightPoint: Identifiable {
    let date: Date
    let completed: Double
    let due: Double
    let missedHabitIDs: [UUID]

    var id: Date { date }
}

private struct InsightRenderPoint: Identifiable {
    let id: Int
    let date: Date
    let completed: Double
    let due: Double
}

private struct HabitDayState: Identifiable {
    let date: Date
    let scheduled: Bool
    let completed: Bool

    var id: Date { date }
}

private struct HabitPerformance: Identifiable {
    let id: UUID
    let title: String
    let percentage: Int
    let days: [HabitDayState]
}

struct InsightsView: View {
    @Environment(\.dismiss) private var dismiss

    let habits: [UIHabit]

    @State private var selectedChartDate: Date?
    @State private var expandedHabitIDs: Set<UUID> = []

    private let totalDays = 40
    private let visibleChartDays = 7

    private var completedSeriesName: String { L10n.t("insights.completed_label") }
    private var dueSeriesName: String { L10n.t("insights.due_label") }
    private let weekRows = 7

    private var debugForcePerfectDays: Bool {
        #if DEBUG
        let raw = ProcessInfo.processInfo.environment["SUNNAD_DEBUG_INSIGHTS_FORCE_PERFECT"]?.lowercased()
        return raw == "1" || raw == "true" || raw == "yes"
        #else
        return false
        #endif
    }

    private var debugExpandAllHabitPerformance: Bool {
        #if DEBUG
        let raw = ProcessInfo.processInfo.environment["SUNNAD_DEBUG_INSIGHTS_EXPAND_ALL"]?.lowercased()
        return raw == "1" || raw == "true" || raw == "yes"
        #else
        return false
        #endif
    }

    private var timelineDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<totalDays).compactMap { index in
            calendar.date(byAdding: .day, value: -(totalDays - 1 - index), to: today)
        }
    }

    private var points: [InsightPoint] {
        let calendar = Calendar.current

        return timelineDays.enumerated().map { index, day in
            let scheduledHabits = habits.filter { $0.isScheduled(on: day, calendar: calendar) }
            var completedHabits = scheduledHabits.filter { completionState(for: $0, on: day, calendar: calendar) }
            var missedHabitIDs = scheduledHabits
                .filter { !completionState(for: $0, on: day, calendar: calendar) }
                .map(\.id)

            if debugForcePerfectDays && index.isMultiple(of: 9) {
                completedHabits = scheduledHabits
                missedHabitIDs = []
            }

            let dueCount = scheduledHabits.count
            let completedCount = min(completedHabits.count, dueCount)
            let dueValue = max(dueCount, completedCount)

            return InsightPoint(
                date: day,
                completed: Double(completedCount),
                due: Double(dueValue),
                missedHabitIDs: missedHabitIDs
            )
        }
    }

    private var renderPoints: [InsightRenderPoint] {
        makeSmoothedRenderPoints(from: points)
    }

    private var renderPointsPadded: [InsightRenderPoint] {
        guard let first = renderPoints.first, let last = renderPoints.last else {
            return renderPoints
        }

        let lead = InsightRenderPoint(
            id: -1,
            date: first.date.addingTimeInterval(-12 * 60 * 60),
            completed: first.completed,
            due: first.due
        )
        let tail = InsightRenderPoint(
            id: renderPoints.count + 1,
            date: last.date.addingTimeInterval(12 * 60 * 60),
            completed: last.completed,
            due: last.due
        )

        return ([lead] + renderPoints + [tail]).sorted { $0.date < $1.date }
    }

    private var selectedPoint: InsightPoint? {
        guard let selectedChartDate else {
            return nil
        }

        return points.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(selectedChartDate)) < abs(rhs.date.timeIntervalSince(selectedChartDate))
        }
    }

    private var maxDueValue: Double {
        Double(max(1, Int(points.map(\.due).max() ?? 0)))
    }

    private var habitPerformance: [HabitPerformance] {
        let calendar = Calendar.current

        return habits.map { habit in
            let dayStates = timelineDays.map { day in
                let scheduled = habit.isScheduled(on: day, calendar: calendar)
                let completed = scheduled && completionState(for: habit, on: day, calendar: calendar)
                return HabitDayState(date: day, scheduled: scheduled, completed: completed)
            }

            let scheduledCount = dayStates.filter(\.scheduled).count
            let completedCount = dayStates.filter(\.completed).count
            let percentage = scheduledCount == 0 ? 0 : Int((Double(completedCount) / Double(scheduledCount) * 100).rounded())

            return HabitPerformance(
                id: habit.id,
                title: habit.displayTitle,
                percentage: percentage,
                days: dayStates
            )
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

                Chart {
                    ForEach(renderPointsPadded) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            yStart: .value("Baseline", 0.0),
                            yEnd: .value(completedSeriesName, point.completed),
                            series: .value("Layer", "completedFill")
                        )
                        .interpolationMethod(.linear)
                        .foregroundStyle(
                            .linearGradient(
                                colors: [SunnadTheme.primary.opacity(0.34), SunnadTheme.primary.opacity(0.00)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .alignsMarkStylesWithPlotArea()
                    }

                    ForEach(renderPointsPadded) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            yStart: .value(completedSeriesName, point.completed),
                            yEnd: .value(dueSeriesName, point.due),
                            series: .value("Layer", "gapFill")
                        )
                        .interpolationMethod(.linear)
                        .foregroundStyle(
                            .linearGradient(
                                colors: [Color.yellow.opacity(0.24), Color.yellow.opacity(0.00)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .alignsMarkStylesWithPlotArea()
                    }

                    ForEach(renderPointsPadded) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value(dueSeriesName, point.due),
                            series: .value("Series", "dueLine")
                        )
                        .interpolationMethod(.linear)
                        .foregroundStyle(Color.yellow)
                        .lineStyle(
                            StrokeStyle(
                                lineWidth: 3,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                    }

                    ForEach(renderPointsPadded) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value(completedSeriesName, point.completed),
                            series: .value("Series", "completedLine")
                        )
                        .interpolationMethod(.linear)
                        .foregroundStyle(SunnadTheme.primary)
                        .lineStyle(
                            StrokeStyle(
                                lineWidth: 3,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                    }

                    if let selectedPoint {
                        RuleMark(x: .value("Selected", selectedPoint.date))
                            .foregroundStyle(Color.secondary.opacity(0.35))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    }
                }
                .padding(.top, 6)
                .chartYScale(domain: 0...(maxDueValue + 0.8))
                .chartXScale(domain: chartDomain)
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: TimeInterval(visibleChartDays * 24 * 60 * 60))
                .chartScrollPosition(initialX: initialChartPosition)
                .chartXSelection(value: $selectedChartDate)
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
                .chartPlotStyle { plot in
                    plot
                        .padding(.leading, 6)
                        .padding(.trailing, 6)
                }
                .frame(height: 220)

                HStack(spacing: 12) {
                    legendItem(color: .yellow, title: dueSeriesName)
                    legendItem(color: SunnadTheme.primary, title: completedSeriesName)
                    Spacer()
                }
                .padding(.top, 2)

                if let selectedPoint {
                    Divider().padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedPoint.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline.weight(.semibold))

                        Text(L10n.t("insights.missed_habits"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        let missedTitles = missedHabitTitles(for: selectedPoint)
                        if missedTitles.isEmpty {
                            Text(L10n.t("insights.none_missed"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(missedTitles, id: \.self) { title in
                                    Text("• \(title)")
                                        .font(.footnote)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }
            }

            SectionHeader(title: L10n.t("insights.habit_performance"))
            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(habitPerformance.enumerated()), id: \.element.id) { index, item in
                        VStack(spacing: 0) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedHabitIDs.contains(item.id) {
                                        expandedHabitIDs.remove(item.id)
                                    } else {
                                        expandedHabitIDs.insert(item.id)
                                    }
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Text(item.title)
                                        .font(.body.weight(.medium))
                                        .lineLimit(1)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Text("\(item.percentage)%")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)

                                    Image(systemName: expandedHabitIDs.contains(item.id) ? "chevron.up" : "chevron.down")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if expandedHabitIDs.contains(item.id) {
                                Divider().padding(.leading, 16)

                                VStack(alignment: .leading, spacing: 10) {
                                    Text(L10n.t("insights.last40days"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    habitGrid(days: item.days)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                        }

                        if index < habitPerformance.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sunnadSolidBars()
        .onAppear {
            guard debugExpandAllHabitPerformance else { return }
            expandedHabitIDs = Set(habitPerformance.map(\.id))
        }
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

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func habitGrid(days: [HabitDayState]) -> some View {
        let columnCount = max(1, Int(ceil(Double(days.count) / Double(weekRows))))
        let columns = Array(repeating: GridItem(.flexible(minimum: 18, maximum: .infinity), spacing: 6), count: columnCount)
        let arrangedCells = arrangedWeekCells(from: days, columns: columnCount)

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(Array(arrangedCells.enumerated()), id: \.offset) { _, day in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color(for: day))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func color(for day: HabitDayState) -> Color {
        if day.completed {
            return SunnadTheme.primary
        }

        if day.scheduled {
            return Color(.systemGray4)
        }

        return Color(.systemGray5).opacity(0.7)
    }

    private func color(for day: HabitDayState?) -> Color {
        guard let day else {
            return Color.clear
        }
        return color(for: day)
    }

    private func arrangedWeekCells(from days: [HabitDayState], columns: Int) -> [HabitDayState?] {
        var cells = Array<HabitDayState?>(repeating: nil, count: weekRows * columns)

        for sourceIndex in days.indices {
            let weekColumn = sourceIndex / weekRows
            let weekdayRow = sourceIndex % weekRows
            let targetIndex = weekdayRow * columns + weekColumn
            cells[targetIndex] = days[sourceIndex]
        }

        return cells
    }

    private func missedHabitTitles(for point: InsightPoint) -> [String] {
        let lookup = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0.displayTitle) })
        return point.missedHabitIDs.compactMap { lookup[$0] }
    }

    private var chartDomain: ClosedRange<Date> {
        guard let first = renderPointsPadded.first?.date, let last = renderPointsPadded.last?.date else {
            let now = Date()
            return now...now
        }
        return first...last
    }

    private var initialChartPosition: Date {
        guard let last = points.last?.date else {
            return Date()
        }

        return Calendar.current.date(byAdding: .day, value: -(visibleChartDays - 1), to: last) ?? last
    }

    private func completionState(for habit: UIHabit, on date: Date, calendar: Calendar) -> Bool {
        guard habit.isScheduled(on: date, calendar: calendar) else {
            return false
        }

        if calendar.isDateInToday(date) {
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

    private func makeSmoothedRenderPoints(from points: [InsightPoint]) -> [InsightRenderPoint] {
        guard points.count > 1 else {
            return points.enumerated().map { index, point in
                InsightRenderPoint(id: index, date: point.date, completed: point.completed, due: point.due)
            }
        }

        let dueValues = points.map(\.due)
        let completedValues = smooth(values: points.map(\.completed), passes: 1)

        let constrainedDaily: [InsightPoint] = points.enumerated().map { index, point in
            let completed = min(max(0, completedValues[index]), dueValues[index])
            let due = max(dueValues[index], completed)
            return InsightPoint(
                date: point.date,
                completed: completed,
                due: due,
                missedHabitIDs: point.missedHabitIDs
            )
        }

        var out: [InsightRenderPoint] = []
        let samplesPerSegment = 6
        var id = 0

        for i in 0..<(constrainedDaily.count - 1) {
            let start = constrainedDaily[i]
            let end = constrainedDaily[i + 1]
            let dt = end.date.timeIntervalSince(start.date)

            for step in 0..<samplesPerSegment {
                let t = Double(step) / Double(samplesPerSegment)
                let date = start.date.addingTimeInterval(dt * t)
                let due = lerp(start.due, end.due, t)
                let completedRaw = lerp(start.completed, end.completed, t)
                let completed = min(max(0, completedRaw), due)
                out.append(InsightRenderPoint(id: id, date: date, completed: completed, due: due))
                id += 1
            }
        }

        if let last = constrainedDaily.last {
            out.append(InsightRenderPoint(id: id, date: last.date, completed: last.completed, due: last.due))
        }

        return out
    }

    private func smooth(values: [Double], passes: Int) -> [Double] {
        guard values.count > 2 else { return values }
        var result = values

        for _ in 0..<passes {
            var next = result
            for index in 1..<(result.count - 1) {
                next[index] = (result[index - 1] * 0.2) + (result[index] * 0.6) + (result[index + 1] * 0.2)
            }
            result = next
        }

        return result
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }
}
