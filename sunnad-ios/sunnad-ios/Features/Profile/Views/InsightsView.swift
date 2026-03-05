import Charts
import SwiftUI

private struct InsightRenderPoint: Identifiable {
    let id: Int
    let date: Date
    let completed: Double
    let due: Double
}

struct InsightsView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: InsightsViewModel

    @State private var selectedChartDate: Date?
    @State private var expandedHabitIDs: Set<UUID> = []
    @State private var didApplyDebugExpansion = false

    private let visibleChartDays = 7
    private let weekRows = 7

    private var completedSeriesName: String { L10n.t("insights.completed_label") }
    private var dueSeriesName: String { L10n.t("insights.due_label") }

    private var debugExpandAllHabitPerformance: Bool {
        #if DEBUG
        let raw = ProcessInfo.processInfo.environment["SUNNAD_DEBUG_INSIGHTS_EXPAND_ALL"]?.lowercased()
        return raw == "1" || raw == "true" || raw == "yes"
        #else
        return false
        #endif
    }

    private var points: [InsightPoint] {
        viewModel.points
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

    var body: some View {
        ScreenScaffold(contentTopPadding: 8) {
            headerRow

            if viewModel.isLoading && points.isEmpty {
                Card {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else if let errorMessage = viewModel.errorMessage, points.isEmpty {
                Card {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                completionTrendSection
                habitPerformanceSection
                if !viewModel.categoryPerformance.isEmpty {
                    categoryPerformanceSection
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sunnadSolidBars()
        .onAppear {
            Task {
                await viewModel.load()
                applyDebugExpansionIfNeeded()
            }
        }
        .onChange(of: viewModel.habitPerformance) { _, _ in
            applyDebugExpansionIfNeeded()
        }
    }

    private var completionTrendSection: some View {
        VStack(spacing: 12) {
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
                .frame(height: 220)
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

                        let missedTitles = viewModel.missedHabitTitles(for: selectedPoint)
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
        }
    }

    private var habitPerformanceSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: L10n.t("insights.habit_performance"))
            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.habitPerformance.enumerated()), id: \.element.id) { index, item in
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

                        if index < viewModel.habitPerformance.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
        }
    }

    private var categoryPerformanceSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: L10n.t("insights.category_analytics"))
            Card(contentPadding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.categoryPerformance.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.title)
                                    .font(.body.weight(.medium))
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)

                                Text(
                                    L10n.t(
                                        "insights.category_completed_ratio",
                                        item.completed,
                                        item.total
                                    )
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                categoryCompletionBar(percentage: item.percentage)
                            }

                            Spacer()

                            Text(L10n.t("insights.percent_complete", item.percentage))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if index < viewModel.categoryPerformance.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func categoryCompletionBar(percentage: Int) -> some View {
        let clamped = min(max(percentage, 0), 100)
        let progress = CGFloat(clamped) / 100.0
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.secondary.opacity(0.16))
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [SunnadTheme.primary, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 7)
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
        let columnCount = weekColumnCount(for: days)
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
        guard !days.isEmpty else {
            return Array<HabitDayState?>(repeating: nil, count: weekRows * columns)
        }

        var calendar = Calendar.current
        calendar.timeZone = .current
        var cells = Array<HabitDayState?>(repeating: nil, count: weekRows * columns)
        let startMonday = mondayStart(for: days[0].date, calendar: calendar)

        for day in days {
            let dayStart = calendar.startOfDay(for: day.date)
            let daysFromStart = calendar.dateComponents([.day], from: startMonday, to: dayStart).day ?? 0
            let weekColumn = max(0, daysFromStart / weekRows)
            let weekdayRow = mondayFirstWeekdayIndex(for: dayStart, calendar: calendar)

            guard weekColumn < columns else {
                continue
            }

            let targetIndex = weekdayRow * columns + weekColumn
            cells[targetIndex] = day
        }

        return cells
    }

    private func weekColumnCount(for days: [HabitDayState]) -> Int {
        guard let first = days.first?.date, let last = days.last?.date else {
            return 1
        }

        var calendar = Calendar.current
        calendar.timeZone = .current

        let startMonday = mondayStart(for: first, calendar: calendar)
        let endMonday = mondayStart(for: last, calendar: calendar)
        let diffDays = calendar.dateComponents([.day], from: startMonday, to: endMonday).day ?? 0
        return max(1, (diffDays / weekRows) + 1)
    }

    private func mondayStart(for date: Date, calendar: Calendar) -> Date {
        let dayStart = calendar.startOfDay(for: date)
        let mondayIndex = mondayFirstWeekdayIndex(for: dayStart, calendar: calendar)
        return calendar.date(byAdding: .day, value: -mondayIndex, to: dayStart) ?? dayStart
    }

    private func mondayFirstWeekdayIndex(for date: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return (weekday + 5) % 7
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

    private func applyDebugExpansionIfNeeded() {
        guard debugExpandAllHabitPerformance, !didApplyDebugExpansion else {
            return
        }
        didApplyDebugExpansion = true
        expandedHabitIDs = Set(viewModel.habitPerformance.map(\.id))
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
