import Foundation

@MainActor
final class AppSessionAnalyticsTracker {
    private let analytics: AnalyticsClient
    private let consumeNotificationOpenSource: () -> String?
    private let now: () -> Date

    private var sessionStartedAt: Date?
    private var offlineStartedAt: Date?
    private var accumulatedOfflineSeconds: TimeInterval = 0
    private var isOnline = true
    private var pendingDeepLinkSource = false

    init(
        analytics: AnalyticsClient,
        consumeNotificationOpenSource: @escaping () -> String?,
        now: @escaping () -> Date = Date.init
    ) {
        self.analytics = analytics
        self.consumeNotificationOpenSource = consumeNotificationOpenSource
        self.now = now
    }

    func markDeepLinkOpened() {
        pendingDeepLinkSource = true
    }

    func updateConnectivity(isOnline: Bool) {
        let current = now()
        guard self.isOnline != isOnline else { return }
        self.isOnline = isOnline

        if isOnline {
            if let offlineStartedAt {
                accumulatedOfflineSeconds += max(0, current.timeIntervalSince(offlineStartedAt))
                self.offlineStartedAt = nil
            }
        } else if sessionStartedAt != nil, offlineStartedAt == nil {
            offlineStartedAt = current
        }
    }

    func appDidBecomeActive() {
        guard sessionStartedAt == nil else { return }
        sessionStartedAt = now()
        if !isOnline, offlineStartedAt == nil {
            offlineStartedAt = sessionStartedAt
        }

        analytics.trackAppLifecycle(.opened(source: resolveOpenSource()))
    }

    func appDidEnterBackground() {
        guard let sessionStartedAt else { return }
        let current = now()
        var offlineSeconds = accumulatedOfflineSeconds
        if let offlineStartedAt {
            offlineSeconds += max(0, current.timeIntervalSince(offlineStartedAt))
        }

        let sessionDuration = max(0, Int(current.timeIntervalSince(sessionStartedAt).rounded()))
        let offlineDuration = max(0, Int(offlineSeconds.rounded()))

        analytics.trackAppLifecycle(.backgrounded(sessionDurationSeconds: sessionDuration))
        if offlineDuration > 0 {
            analytics.trackAppLifecycle(
                .offlineSessionCompleted(
                    sessionDurationSeconds: sessionDuration,
                    offlineDurationSeconds: offlineDuration
                )
            )
        }

        self.sessionStartedAt = nil
        self.offlineStartedAt = nil
        self.accumulatedOfflineSeconds = 0
    }

    private func resolveOpenSource() -> String {
        if let notificationSource = consumeNotificationOpenSource() {
            pendingDeepLinkSource = false
            return notificationSource
        }

        if pendingDeepLinkSource {
            pendingDeepLinkSource = false
            return "deep_link"
        }

        return "organic"
    }
}
