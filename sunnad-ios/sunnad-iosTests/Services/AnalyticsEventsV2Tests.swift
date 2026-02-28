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

    @Test
    func trackAppLifecycleCapturesOpenedSource() throws {
        let analytics = TestAnalyticsClient()

        analytics.trackAppLifecycle(.opened(source: "notification"))

        let captured = try #require(analytics.captures.last)
        #expect(captured.event == "app_opened")
        #expect(captured.properties?["source"] as? String == "notification")
    }

    @Test
    func trackStreakCapturesMilestoneAndBreakEvents() throws {
        let analytics = TestAnalyticsClient()

        analytics.trackStreak(.achieved(habitType: "binary", streakLength: 7, milestone: 7))
        analytics.trackStreak(.broken(habitType: "binary", previousStreakLength: 4))

        let achieved = analytics.captures.first(where: { $0.event == "habit_streak_achieved" })
        #expect(achieved?.properties?["milestone"] as? Int == 7)

        let broken = analytics.captures.first(where: { $0.event == "habit_streak_broken" })
        #expect(broken?.properties?["previous_streak_length"] as? Int == 4)
    }

    @Test
    func trackNotificationCapturesReceivedAndTapped() throws {
        let analytics = TestAnalyticsClient()

        analytics.trackNotification(.received(notificationType: "quote", source: "local"))
        analytics.trackNotification(.tapped(notificationType: "quote", source: "local"))

        #expect(analytics.captures.contains(where: { $0.event == "notification_received" }))
        #expect(analytics.captures.contains(where: { $0.event == "notification_tapped" }))
    }
}
