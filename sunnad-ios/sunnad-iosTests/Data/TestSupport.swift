import Foundation
import SwiftData
@testable import sunnad_ios

final class TestLogger: AnalyticsLogging, @unchecked Sendable {
    private(set) var events: [(AnalyticsEvent, [String: String])] = []

    func log(_ event: AnalyticsEvent, metadata: [String: String]) {
        events.append((event, metadata))
    }
}

final class TestAnalyticsClient: AnalyticsClient, @unchecked Sendable {
    private(set) var captures: [(event: String, properties: [String: Any]?)] = []
    private(set) var screens: [(name: String, properties: [String: Any]?)] = []
    private(set) var identifies: [(distinctId: String, userProperties: [String: Any]?, setOnce: [String: Any]?)] = []
    private(set) var personPropertiesUpdates: [(properties: [String: Any], setOnce: [String: Any]?)] = []
    private(set) var didReset = false
    private(set) var lastEnabled: Bool?

    func capture(_ event: String, properties: [String: Any]?) {
        captures.append((event: event, properties: properties))
    }

    func screen(_ name: String, properties: [String: Any]?) {
        screens.append((name: name, properties: properties))
    }

    func identify(_ distinctId: String, userProperties: [String: Any]?, userPropertiesSetOnce: [String: Any]?) {
        identifies.append((distinctId: distinctId, userProperties: userProperties, setOnce: userPropertiesSetOnce))
    }

    func setPersonProperties(_ properties: [String: Any], setOnce: [String: Any]?) {
        personPropertiesUpdates.append((properties: properties, setOnce: setOnce))
    }

    func reset() {
        didReset = true
    }

    func setEnabled(_ isEnabled: Bool) {
        lastEnabled = isEnabled
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
