import AudioToolbox
import UIKit

protocol InteractionFeedbackClient {
    func dhikrIncremented(hapticsEnabled: Bool)
    func dhikrTargetReached(hapticsEnabled: Bool, soundsEnabled: Bool)
    func habitCompleted(hapticsEnabled: Bool)
    func destructiveAction(hapticsEnabled: Bool)
    func groupNudgeSent(hapticsEnabled: Bool)
}

@MainActor
final class SystemInteractionFeedbackClient: InteractionFeedbackClient {
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let successImpact = UIImpactFeedbackGenerator(style: .medium)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    func dhikrIncremented(hapticsEnabled: Bool) {
        guard hapticsEnabled else { return }
        lightImpact.prepare()
        lightImpact.impactOccurred(intensity: 0.9)
    }

    func dhikrTargetReached(hapticsEnabled: Bool, soundsEnabled: Bool) {
        if hapticsEnabled {
            notification.prepare()
            notification.notificationOccurred(.success)
        }
        if soundsEnabled {
            AudioServicesPlaySystemSound(1104)
        }
    }

    func habitCompleted(hapticsEnabled: Bool) {
        guard hapticsEnabled else { return }
        selection.prepare()
        selection.selectionChanged()
    }

    func destructiveAction(hapticsEnabled: Bool) {
        guard hapticsEnabled else { return }
        notification.prepare()
        notification.notificationOccurred(.warning)
    }

    func groupNudgeSent(hapticsEnabled: Bool) {
        guard hapticsEnabled else { return }
        successImpact.prepare()
        successImpact.impactOccurred(intensity: 0.75)
    }
}

final class NoopInteractionFeedbackClient: InteractionFeedbackClient {
    func dhikrIncremented(hapticsEnabled: Bool) {}

    func dhikrTargetReached(hapticsEnabled: Bool, soundsEnabled: Bool) {}

    func habitCompleted(hapticsEnabled: Bool) {}

    func destructiveAction(hapticsEnabled: Bool) {}

    func groupNudgeSent(hapticsEnabled: Bool) {}
}
