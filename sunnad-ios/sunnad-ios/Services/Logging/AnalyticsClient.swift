import Foundation

protocol AnalyticsClient {
    func capture(_ event: String, properties: [String: Any]?)
    func screen(_ name: String, properties: [String: Any]?)
    func identify(_ distinctId: String, userProperties: [String: Any]?, userPropertiesSetOnce: [String: Any]?)
    func setPersonProperties(_ properties: [String: Any], setOnce: [String: Any]?)
    func reset()
    func setEnabled(_ isEnabled: Bool)
}

final class NoopAnalyticsClient: AnalyticsClient {
    func capture(_ event: String, properties: [String: Any]?) {}

    func screen(_ name: String, properties: [String: Any]?) {}

    func identify(_ distinctId: String, userProperties: [String: Any]?, userPropertiesSetOnce: [String: Any]?) {}

    func setPersonProperties(_ properties: [String: Any], setOnce: [String: Any]?) {}

    func reset() {}

    func setEnabled(_ isEnabled: Bool) {}
}
