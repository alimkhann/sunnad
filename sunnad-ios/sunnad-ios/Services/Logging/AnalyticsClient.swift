import Foundation
import PostHog

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

final class PostHogAnalyticsClient: AnalyticsClient {
    private enum LocalStateKeys {
        static let replaySampled = "sunnad.analytics.replay.sampled"
    }

    private let environment: AppEnvironment
    private var isEnabled: Bool
    private let baseEventProperties: [String: Any]

    init?(environment: AppEnvironment) {
        self.environment = environment

        guard let apiKey = PostHogAnalyticsClient.resolveAPIKey() else {
            // If we cannot resolve a key, fall back to a noop client by returning nil.
            return nil
        }

        let host = PostHogAnalyticsClient.resolveHost()
        let enabledByEnv = PostHogAnalyticsClient.resolveEnabledFlag(environment: environment)
        self.isEnabled = enabledByEnv

        let config = PostHogConfig(apiKey: apiKey, host: host)
        // Prefer explicit, manual tracking. We rely on our own events instead of autocapture.
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        config.captureElementInteractions = false
        config.enableSwizzling = false
        config.reuseAnonymousId = true
        config.optOut = !enabledByEnv
        #if os(iOS)
        config.sessionReplay = PostHogAnalyticsClient.resolveReplayEnabled(environment: environment)
        config.sessionReplayConfig.maskAllTextInputs = true
        config.sessionReplayConfig.captureNetworkTelemetry = false
        #endif

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        let locale = Locale.current.identifier

        self.baseEventProperties = [
            "app_version": appVersion,
            "build_number": buildNumber,
            "platform": "ios",
            "surface": "ios",
            "schema_version": 2,
            "environment": environment.rawValue,
            "locale": locale,
        ]

        PostHogSDK.shared.setup(config)
    }

    func capture(_ event: String, properties: [String: Any]?) {
        guard isEnabled else { return }

        var merged = baseEventProperties
        if let properties {
            for (key, value) in properties {
                merged[key] = value
            }
        }

        PostHogSDK.shared.capture(event, properties: merged, userProperties: nil)
    }

    func screen(_ name: String, properties: [String: Any]?) {
        guard isEnabled else { return }

        var merged = baseEventProperties
        if let properties {
            for (key, value) in properties {
                merged[key] = value
            }
        }

        PostHogSDK.shared.screen(name, properties: merged)
    }

    func identify(_ distinctId: String, userProperties: [String: Any]?, userPropertiesSetOnce: [String: Any]?) {
        guard isEnabled else { return }

        PostHogSDK.shared.identify(
            distinctId,
            userProperties: userProperties,
            userPropertiesSetOnce: userPropertiesSetOnce
        )
    }

    func setPersonProperties(_ properties: [String: Any], setOnce: [String: Any]?) {
        guard isEnabled else { return }
        guard !properties.isEmpty || (setOnce?.isEmpty == false) else { return }
        PostHogSDK.shared.setPersonProperties(
            userPropertiesToSet: properties,
            userPropertiesToSetOnce: setOnce
        )
    }

    func reset() {
        PostHogSDK.shared.reset()
    }

    func setEnabled(_ isEnabled: Bool) {
        self.isEnabled = isEnabled
        if isEnabled {
            if PostHogSDK.shared.responds(to: #selector(PostHogSDK.optIn)) {
                PostHogSDK.shared.optIn()
            }
        } else {
            PostHogSDK.shared.optOut()
        }
    }
}

// MARK: - Configuration helpers

private extension PostHogAnalyticsClient {
    static func resolveAPIKey() -> String? {
        // Prefer a runtime override for flexibility in development.
        if let fromEnv = ProcessInfo.processInfo.environment["SUNNAD_POSTHOG_API_KEY"],
           !fromEnv.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fromEnv
        }

        // Fallback to Info.plist if configured there.
        if let fromPlist = Bundle.main.object(forInfoDictionaryKey: "SunnadPosthogApiKey") as? String {
            let trimmed = fromPlist
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return nil
    }

    static func resolveHost() -> String {
        if let fromEnv = ProcessInfo.processInfo.environment["SUNNAD_POSTHOG_HOST"],
           !fromEnv.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fromEnv
        }

        if let fromPlist = Bundle.main.object(forInfoDictionaryKey: "SunnadPosthogHost") as? String {
            let trimmed = fromPlist
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        // Default to EU project as requested.
        return "https://eu.i.posthog.com"
    }

    static func resolveEnabledFlag(environment: AppEnvironment) -> Bool {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["SUNNAD_ANALYTICS_ENABLED"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           !raw.isEmpty {
            return raw == "1" || raw == "true" || raw == "yes"
        }
        #endif

        switch environment {
        case .production:
            return true
        case .development:
            return false
        }
    }

    static func resolveReplayEnabled(environment: AppEnvironment) -> Bool {
        if environment == .development {
            return true
        }

        let defaults = UserDefaults.standard
        if defaults.object(forKey: LocalStateKeys.replaySampled) != nil {
            return defaults.bool(forKey: LocalStateKeys.replaySampled)
        }

        let sampled = Double.random(in: 0...1) < 0.2
        defaults.set(sampled, forKey: LocalStateKeys.replaySampled)
        return sampled
    }
}
