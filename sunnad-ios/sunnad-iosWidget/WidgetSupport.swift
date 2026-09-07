import AppIntents
import CoreFoundation
import Foundation
import SwiftUI
import UIKit
import WidgetKit

enum WidgetTheme {
    static let primary = Color.green
    static let surface = Color(.secondarySystemGroupedBackground)
    static let background = Color(.systemGroupedBackground)
}

enum WidgetSupport {
    static let storeChangedDarwinNotification = "adat.widgetstore.changed"

    static func todayDayKey(calendar: Calendar = .current, timeZone: TimeZone = .current) -> String {
        var resolvedCalendar = calendar
        resolvedCalendar.timeZone = timeZone
        let components = resolvedCalendar.dateComponents([.year, .month, .day], from: Date())
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func isStale(_ snapshot: TodaySnapshot?, date: Date) -> Bool {
        guard let snapshot, !snapshot.dateKey.isEmpty else {
            return true
        }
        return snapshot.dateKey != todayDayKey()
    }

    static func postStoreChanged() {
        let name = CFNotificationName(storeChangedDarwinNotification as CFString)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            name,
            nil,
            nil,
            true
        )
    }
}

struct WidgetSnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: TodaySnapshot?
    let configurationHabit: WidgetHabitEntity?
    let configurationDhikr: WidgetDhikrEntity?
}

struct SnapshotTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetSnapshotEntry {
        WidgetSnapshotEntry(date: Date(), snapshot: nil, configurationHabit: nil, configurationDhikr: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetSnapshotEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetSnapshotEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .never))
    }

    private func entry() -> WidgetSnapshotEntry {
        WidgetSnapshotEntry(
            date: Date(),
            snapshot: WidgetSharedStore.makeShared()?.readSnapshot(),
            configurationHabit: nil,
            configurationDhikr: nil
        )
    }
}

struct ConfigurableSnapshotProvider<Intent: WidgetConfigurationIntent>: AppIntentTimelineProvider {
    let mapConfiguration: (Intent) -> (habit: WidgetHabitEntity?, dhikr: WidgetDhikrEntity?)

    func placeholder(in context: Context) -> WidgetSnapshotEntry {
        WidgetSnapshotEntry(date: Date(), snapshot: nil, configurationHabit: nil, configurationDhikr: nil)
    }

    func snapshot(for configuration: Intent, in context: Context) async -> WidgetSnapshotEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<WidgetSnapshotEntry> {
        Timeline(entries: [entry(for: configuration)], policy: .never)
    }

    private func entry(for configuration: Intent) -> WidgetSnapshotEntry {
        let mapped = mapConfiguration(configuration)
        return WidgetSnapshotEntry(
            date: Date(),
            snapshot: WidgetSharedStore.makeShared()?.readSnapshot(),
            configurationHabit: mapped.habit,
            configurationDhikr: mapped.dhikr
        )
    }
}

struct WidgetHabitEntity: AppEntity, Identifiable, Hashable, Codable, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("widgets.intents.param.habit"))
    static let defaultQuery = WidgetHabitQuery()

    let id: String
    let title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct WidgetHabitQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetHabitEntity] {
        allHabits().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [WidgetHabitEntity] {
        allHabits()
    }

    func defaultResult() async throws -> WidgetHabitEntity? {
        allHabits().first
    }

    private func allHabits() -> [WidgetHabitEntity] {
        guard let snapshot = WidgetSharedStore.makeShared()?.readSnapshot() else {
            return []
        }
        return snapshot.habits.map { habit in
            WidgetHabitEntity(id: habit.id.uuidString, title: habit.title)
        }
    }
}

struct WidgetDhikrEntity: AppEntity, Identifiable, Hashable, Codable, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource("widgets.intents.param.habit"))
    static let defaultQuery = WidgetDhikrQuery()

    let id: String
    let title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct WidgetDhikrQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetDhikrEntity] {
        allDhikrHabits().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [WidgetDhikrEntity] {
        allDhikrHabits()
    }

    func defaultResult() async throws -> WidgetDhikrEntity? {
        allDhikrHabits().first
    }

    private func allDhikrHabits() -> [WidgetDhikrEntity] {
        guard let snapshot = WidgetSharedStore.makeShared()?.readSnapshot() else {
            return []
        }
        return snapshot.habits
            .filter(\.isDhikr)
            .map { habit in
                WidgetDhikrEntity(id: habit.id.uuidString, title: habit.title)
            }
    }
}
