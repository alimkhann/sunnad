import Foundation
import Testing
@testable import sunnad_ios

@MainActor
struct AppRouteStateAnalyticsTests {
    @Test
    func addCustomHabitEmitsHabitCreatedEvent() async throws {
        let analytics = TestAnalyticsClient()
        let dependencies = DependencyContainer(
            modelContainer: try makeInMemoryContainer(),
            analytics: analytics,
            authService: FakeAuthService(currentUserValue: nil),
            deviceTokenSyncService: FakeDeviceTokenSyncService()
        )
        let state = AppRouteState(dependencies: dependencies)

        state.addCustomHabit(
            name: "Read",
            iconSystemName: "book.fill",
            category: .spiritual,
            categoryCustom: nil,
            schedule: .weekly,
            weekdays: [2, 4],
            reminderTime: UIFixtures.time(hour: 9, minute: 0),
            hasDhikrCounter: false
        )

        let captured = try #require(analytics.captures.last(where: { $0.event == "habit_created" }))
        #expect(captured.properties?["type"] as? String == "binary")
        #expect(captured.properties?["schedule_type"] as? String == "weekly")
        #expect(captured.properties?["has_reminder"] as? Bool == true)
        #expect(captured.properties?["target_count"] as? Int == 0)
        _ = state
    }

    @Test
    func quoteOpenAndShareEmitQuoteEvents() async throws {
        let analytics = TestAnalyticsClient()
        let dependencies = DependencyContainer(
            modelContainer: try makeInMemoryContainer(),
            analytics: analytics,
            authService: FakeAuthService(currentUserValue: nil),
            deviceTokenSyncService: FakeDeviceTokenSyncService()
        )
        let state = AppRouteState(dependencies: dependencies)

        state.openQuoteOfDay()
        state.trackQuoteShared(channel: "system_share_sheet")

        let opened = try #require(analytics.captures.last(where: { $0.event == "quote_opened" }))
        #expect(opened.event == "quote_opened")

        let shared = try #require(analytics.captures.last(where: { $0.event == "quote_shared" }))
        #expect(shared.properties?["channel"] as? String == "system_share_sheet")
        #expect(state.rootSheet == .quoteOfDay)
    }
}
