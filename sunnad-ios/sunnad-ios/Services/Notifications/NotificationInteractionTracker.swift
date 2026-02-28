import Foundation
import UserNotifications

@MainActor
protocol NotificationInteractionTracking: AnyObject {
    func register()
    func consumePendingOpenSource() -> String?
}

@MainActor
final class UserNotificationInteractionTracker: NSObject, NotificationInteractionTracking {
    private let analytics: AnalyticsClient
    private let center: UNUserNotificationCenter
    private var pendingOpenSource: String?

    init(
        analytics: AnalyticsClient,
        center: UNUserNotificationCenter = .current()
    ) {
        self.analytics = analytics
        self.center = center
    }

    func register() {
        center.delegate = self
    }

    func consumePendingOpenSource() -> String? {
        defer { pendingOpenSource = nil }
        return pendingOpenSource
    }

    private func notificationType(from userInfo: [AnyHashable: Any]) -> String {
        if userInfo["habit_id"] != nil {
            return "habit"
        }
        if let type = userInfo["type"] as? String {
            if type == "quote_of_day" {
                return "quote"
            }
            if type.contains("group") {
                return "group"
            }
        }
        return "unknown"
    }
}

@MainActor
extension UserNotificationInteractionTracker: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        _ = center
        analytics.trackNotification(
            .received(
                notificationType: notificationType(from: notification.request.content.userInfo),
                source: "local"
            )
        )
        completionHandler([])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        _ = center
        let type = notificationType(from: response.notification.request.content.userInfo)
        analytics.trackNotification(.tapped(notificationType: type, source: "local"))
        pendingOpenSource = "notification"
        completionHandler()
    }
}

@MainActor
final class NoopNotificationInteractionTracker: NotificationInteractionTracking {
    func register() {}

    func consumePendingOpenSource() -> String? {
        nil
    }
}
