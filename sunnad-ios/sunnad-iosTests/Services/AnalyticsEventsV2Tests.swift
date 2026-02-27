import Foundation
import Testing
@testable import sunnad_ios

@MainActor
struct AnalyticsEventsV2Tests {
    @Test
    func trackScreenCapturesScreenViewedEvent() throws {
        let analytics = TestAnalyticsClient()

        analytics.trackScreen(.today)

        let captured = try #require(analytics.captures.last)
        #expect(captured.event == "screen_viewed")
        #expect(captured.properties?["screen_name"] as? String == "today")
    }

    @Test
    func trackScreenCapturesInsightsScreen() throws {
        let analytics = TestAnalyticsClient()

        analytics.trackScreen(.insights)

        let captured = try #require(analytics.captures.last)
        #expect(captured.event == "screen_viewed")
        #expect(captured.properties?["screen_name"] as? String == "insights")
    }

    @Test
    func trackAuthCapturesAuthResultWithReason() throws {
        let analytics = TestAnalyticsClient()

        analytics.trackAuth(
            kind: .signIn,
            provider: .email,
            status: .failure,
            reason: "error"
        )

        let captured = try #require(analytics.captures.last)
        #expect(captured.event == "auth_result")
        #expect(captured.properties?["kind"] as? String == "sign_in")
        #expect(captured.properties?["provider"] as? String == "email")
        #expect(captured.properties?["status"] as? String == "failure")
        #expect(captured.properties?["reason"] as? String == "error")
    }

    @Test
    func trackHabitCompletionCapturesV2ToggleEvent() throws {
        let analytics = TestAnalyticsClient()

        analytics.trackHabit(.completionToggled(type: "binary", status: "completed", source: "today"))

        let captured = try #require(analytics.captures.last)
        #expect(captured.event == "habit_completion_toggled")
        #expect(captured.properties?["type"] as? String == "binary")
        #expect(captured.properties?["status"] as? String == "completed")
        #expect(captured.properties?["source"] as? String == "today")
    }

    @Test
    func trackSyncCapturesSyncCycleResult() throws {
        let analytics = TestAnalyticsClient()

        analytics.trackSync(
            .result(
                trigger: "manual",
                status: "failed",
                durationMs: 1300,
                pulled: 4,
                pushed: 2,
                stage: "sync_cycle",
                code: "domain#1"
            )
        )

        let captured = try #require(analytics.captures.last)
        #expect(captured.event == "sync_cycle_result")
        #expect(captured.properties?["trigger"] as? String == "manual")
        #expect(captured.properties?["status"] as? String == "failed")
        #expect(captured.properties?["duration_ms"] as? Int == 1300)
        #expect(captured.properties?["pulled_count"] as? Int == 4)
        #expect(captured.properties?["pushed_count"] as? Int == 2)
        #expect(captured.properties?["stage"] as? String == "sync_cycle")
        #expect(captured.properties?["error_code"] as? String == "domain#1")
    }
}
