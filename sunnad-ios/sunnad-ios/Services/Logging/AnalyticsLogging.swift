import Foundation

enum AnalyticsEvent: String, Sendable {
    case habitCreated
    case habitUpdated
    case habitDeleted
    case habitToggled
    case completionUpserted
    case quoteSaved
    case todayLoaded
    case reminderPermissionRequested
    case reminderSynced
    case reminderRemoved
    case storageFailure
    case syncStarted
    case syncFinished
}

protocol AnalyticsLogging: Sendable {
    func log(_ event: AnalyticsEvent, metadata: [String: String])
}
