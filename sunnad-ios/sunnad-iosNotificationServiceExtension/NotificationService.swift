import Foundation
import UserNotifications

// Prewired scaffold for OneSignal Notification Service Extension.
// The extension target/capabilities can be added in Xcode when APNs certs are available.
final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        // OneSignal SDK hook can be enabled here once the extension target is linked.
        contentHandler(bestAttemptContent)
    }

    override func serviceExtensionTimeWillExpire() {
        guard let contentHandler, let bestAttemptContent else { return }
        contentHandler(bestAttemptContent)
    }
}
