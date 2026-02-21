import Foundation
import SwiftData
@testable import sunnad_ios

final class TestLogger: AnalyticsLogging, @unchecked Sendable {
    private(set) var events: [(AnalyticsEvent, [String: String])] = []

    func log(_ event: AnalyticsEvent, metadata: [String: String]) {
        events.append((event, metadata))
    }
}

@MainActor
func makeInMemoryContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: HabitEntity.self,
        CompletionEntity.self,
        QuoteEntity.self,
        SavedQuoteEntity.self,
        DiagnosticEventEntity.self,
        LocalOutboxEventEntity.self,
        LocalSyncCursorEntity.self,
        LocalGroupSyncEntity.self,
        LocalGroupMemberSyncEntity.self,
        LocalGroupSharedHabitSyncEntity.self,
        configurations: configuration
    )
}

@MainActor
func makeTestOwnerScopeResolver(namespace: String = UUID().uuidString) -> LocalOwnerScopeResolver {
    let defaults = UserDefaults(suiteName: "sunnad.tests.\(namespace)") ?? .standard
    defaults.removePersistentDomain(forName: "sunnad.tests.\(namespace)")
    return LocalOwnerScopeResolver(namespace: namespace, userDefaults: defaults)
}
