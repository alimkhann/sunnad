import Foundation
import OSLog
import SwiftData

final class LocalDiagnosticsStore {
    private let modelContext: ModelContext
    private let maxEntries: Int

    init(modelContext: ModelContext, maxEntries: Int = 300) {
        self.modelContext = modelContext
        self.maxEntries = maxEntries
    }

    func append(event: AnalyticsEvent, metadata: [String: String]) {
        #if DEBUG
        let metadataString = metadata
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: ",")

        modelContext.insert(
            DiagnosticEventEntity(
                event: event.rawValue,
                metadata: metadataString,
                createdAt: Date()
            )
        )

        trimIfNeeded()
        try? modelContext.save()
        #endif
    }

    private func trimIfNeeded() {
        #if DEBUG
        let descriptor = FetchDescriptor<DiagnosticEventEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        guard let all = try? modelContext.fetch(descriptor), all.count > maxEntries else {
            return
        }

        for event in all.dropFirst(maxEntries) {
            modelContext.delete(event)
        }
        #endif
    }
}

final class OSLogAnalyticsLogger: AnalyticsLogging, @unchecked Sendable {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.sunnad.app"

    private let habitLogger = Logger(subsystem: subsystem, category: "habit")
    private let completionLogger = Logger(subsystem: subsystem, category: "completion")
    private let quoteLogger = Logger(subsystem: subsystem, category: "quote")
    private let notificationLogger = Logger(subsystem: subsystem, category: "notification")
    private let storageLogger = Logger(subsystem: subsystem, category: "storage")
    private let syncLogger = Logger(subsystem: subsystem, category: "sync")

    private let diagnosticsStore: LocalDiagnosticsStore?

    init(diagnosticsStore: LocalDiagnosticsStore? = nil) {
        self.diagnosticsStore = diagnosticsStore
    }

    func log(_ event: AnalyticsEvent, metadata: [String: String] = [:]) {
        let payload = metadata
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: ",")

        let message = payload.isEmpty ? event.rawValue : "\(event.rawValue) \(payload)"

        logger(for: event).info("\(message, privacy: .public)")

        if let diagnosticsStore {
            Task { @MainActor in
                diagnosticsStore.append(event: event, metadata: metadata)
            }
        }
    }

    private func logger(for event: AnalyticsEvent) -> Logger {
        switch event {
        case .habitCreated, .habitUpdated, .habitDeleted, .habitToggled:
            return habitLogger
        case .completionUpserted:
            return completionLogger
        case .quoteSaved, .todayLoaded:
            return quoteLogger
        case .reminderPermissionRequested, .reminderSynced, .reminderRemoved:
            return notificationLogger
        case .storageFailure:
            return storageLogger
        case .syncStarted, .syncFinished:
            return syncLogger
        }
    }
}
