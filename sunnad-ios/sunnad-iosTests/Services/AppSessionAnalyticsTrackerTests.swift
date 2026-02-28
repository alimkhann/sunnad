import Foundation
import Testing
@testable import sunnad_ios

@MainActor
struct AppSessionAnalyticsTrackerTests {
    @Test
    func appSessionTracksOpenAndBackgroundDuration() throws {
        let analytics = TestAnalyticsClient()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var now = start
        let tracker = AppSessionAnalyticsTracker(
            analytics: analytics,
            consumeNotificationOpenSource: { nil },
            now: { now }
        )

        tracker.appDidBecomeActive()
        now = start.addingTimeInterval(95)
        tracker.appDidEnterBackground()

        let opened = try #require(analytics.captures.first(where: { $0.event == "app_opened" }))
        #expect(opened.properties?["source"] as? String == "organic")

        let backgrounded = try #require(analytics.captures.first(where: { $0.event == "app_backgrounded" }))
        #expect(backgrounded.properties?["session_duration_seconds"] as? Int == 95)
    }

    @Test
    func appSessionTracksOfflineDuration() throws {
        let analytics = TestAnalyticsClient()
        let start = Date(timeIntervalSince1970: 1_700_000_100)
        var now = start
        let tracker = AppSessionAnalyticsTracker(
            analytics: analytics,
            consumeNotificationOpenSource: { nil },
            now: { now }
        )

        tracker.appDidBecomeActive()
        tracker.updateConnectivity(isOnline: false)
        now = start.addingTimeInterval(30)
        tracker.updateConnectivity(isOnline: true)
        now = start.addingTimeInterval(40)
        tracker.appDidEnterBackground()

        let offline = try #require(analytics.captures.first(where: { $0.event == "offline_session_completed" }))
        #expect(offline.properties?["session_duration_seconds"] as? Int == 40)
        #expect(offline.properties?["offline_duration_seconds"] as? Int == 30)
    }

    @Test
    func appSessionPrefersNotificationOpenSource() throws {
        let analytics = TestAnalyticsClient()
        var pendingSource: String? = "notification"
        let tracker = AppSessionAnalyticsTracker(
            analytics: analytics,
            consumeNotificationOpenSource: {
                defer { pendingSource = nil }
                return pendingSource
            }
        )

        tracker.appDidBecomeActive()
        let opened = try #require(analytics.captures.first(where: { $0.event == "app_opened" }))
        #expect(opened.properties?["source"] as? String == "notification")
    }
}
