import Foundation
import Testing
@testable import sunnad_ios

struct AnalyticsErrorBridgeLoggerTests {
    @Test
    func storageFailureEmitsSanitizedAnalyticsEvent() throws {
        let analytics = TestAnalyticsClient()
        let baseLogger = CapturingLogger()
        let logger = AnalyticsErrorBridgeLogger(baseLogger: baseLogger, analyticsClient: analytics, dedupeWindow: 60)

        logger.log(
            .storageFailure,
            metadata: [
                "scope": "sync_cycle",
                "error": "HTTP status=500 while syncing payload",
            ]
        )

        let captured = try #require(analytics.captures.first(where: { $0.event == "ios_error_captured" }))
        #expect(captured.properties?["scope"] as? String == "sync_cycle")
        #expect(captured.properties?["error_kind"] as? String == "sync_failure")
        #expect(captured.properties?["error_code"] as? String == "500")
        #expect(captured.properties?["message_hash"] as? String != nil)
        #expect(captured.properties?["error"] == nil)
        #expect(baseLogger.entries.count == 1)
    }

    @Test
    func duplicateStorageFailureIsDedupedWithinWindow() throws {
        let analytics = TestAnalyticsClient()
        let baseLogger = CapturingLogger()
        let logger = AnalyticsErrorBridgeLogger(baseLogger: baseLogger, analyticsClient: analytics, dedupeWindow: 120)

        let metadata = [
            "scope": "today_toggle",
            "error": "database write failed code:409",
        ]
        logger.log(.storageFailure, metadata: metadata)
        logger.log(.storageFailure, metadata: metadata)

        #expect(analytics.captures.filter { $0.event == "ios_error_captured" }.count == 1)
        #expect(baseLogger.entries.count == 2)
    }
}

private final class CapturingLogger: AnalyticsLogging, @unchecked Sendable {
    private(set) var entries: [(AnalyticsEvent, [String: String])] = []

    func log(_ event: AnalyticsEvent, metadata: [String: String]) {
        entries.append((event, metadata))
    }
}
