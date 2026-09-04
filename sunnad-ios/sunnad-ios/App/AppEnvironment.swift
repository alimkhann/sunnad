import Combine
import Foundation

enum APNsEnvironmentResolver {
    static func embeddedProvisioningEnvironment(bundle: Bundle = .main) -> String? {
        guard let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return environment(inProvisioningProfile: data)
    }

    static func environment(inProvisioningProfile data: Data) -> String? {
        let profile = String(decoding: data, as: UTF8.self)
        guard let keyRange = profile.range(of: "<key>aps-environment</key>") else {
            return nil
        }
        let suffix = profile[keyRange.upperBound...]
        guard let openingTag = suffix.range(of: "<string>"),
              let closingTag = suffix.range(of: "</string>", range: openingTag.upperBound..<suffix.endIndex) else {
            return nil
        }
        let value = suffix[openingTag.upperBound..<closingTag.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value == "development" || value == "production" ? value : nil
    }
}

enum AppEnvironment: String {
    case development
    case production

    var publicAppLink: URL {
        if let override = ProcessInfo.processInfo.environment["SUNNAD_PUBLIC_APP_LINK"],
           let url = URL(string: override), !override.isEmpty {
            return url
        }

        return localizedPublicURL()
    }

    var privacyURL: URL {
        localizedPublicURL(path: "privacy")
    }

    var termsURL: URL {
        localizedPublicURL(path: "terms")
    }

    var helpURL: URL {
        localizedPublicURL(fragment: "faq")
    }

    private func localizedPublicURL(path: String? = nil, fragment: String? = nil) -> URL {
        var components = URLComponents(string: "https://adatapp.vercel.app")!
        components.path = "/\(L10n.languageCode)" + (path.map { "/\($0)" } ?? "")
        components.fragment = fragment
        return components.url!
    }

    var authRedirectURL: URL {
        if let configured = bundleString("SunnadAuthRedirectURL"),
           let url = URL(string: configured) {
            return url
        }

        if let override = debugResolveEnv(["SUNNAD_AUTH_REDIRECT_URL"]),
           let url = URL(string: override) {
            return url
        }

        return URL(string: "adat://auth-callback")!
    }

    struct SupabaseConfig {
        let url: URL
        let anonKey: String
    }

    struct OAuthConfig {
        let googleEnabled: Bool
        let appleEnabled: Bool
    }

    var oauthConfig: OAuthConfig {
        var googleEnabled = bundleBool("SunnadAuthGoogleEnabled") ?? true
        var appleEnabled = bundleBool("SunnadAuthAppleEnabled") ?? false

        if let envGoogle = debugResolveBoolEnvOptional("SUNNAD_AUTH_GOOGLE_ENABLED") {
            googleEnabled = envGoogle
        }
        if let envApple = debugResolveBoolEnvOptional("SUNNAD_AUTH_APPLE_ENABLED") {
            appleEnabled = envApple
        }

        return OAuthConfig(googleEnabled: googleEnabled, appleEnabled: appleEnabled)
    }

    var otpResendCooldownSeconds: Int {
        if let value = bundleInt("SunnadAuthResendCooldownSeconds"),
           value >= 30 {
            return value
        }

        if let raw = debugResolveEnv(["SUNNAD_AUTH_RESEND_COOLDOWN_SECONDS"]),
           let value = Int(raw),
           value >= 30 {
            return value
        }

        return 120
    }

    var storageNamespace: String {
        if let configured = bundleString("SunnadStorageNamespace"), !configured.isEmpty {
            return configured
        }

        if let override = debugResolveEnv(["SUNNAD_STORAGE_NAMESPACE"]), !override.isEmpty {
            return override
        }

        if let host = supabaseConfig?.url.host?.lowercased(), !host.isEmpty {
            return host.replacingOccurrences(of: ".", with: "-")
        }

        return "default"
    }

    var apnsEnvironment: String {
        if let signedEnvironment = APNsEnvironmentResolver.embeddedProvisioningEnvironment() {
            return signedEnvironment
        }

        if let configured = bundleString("SunnadAPNsEnvironment"),
           configured == "development" || configured == "production" {
            return configured
        }

        if let override = debugResolveEnv(["SUNNAD_APNS_ENVIRONMENT"]),
           override == "development" || override == "production" {
            return override
        }

        return self == .development ? "development" : "production"
    }

    var supabaseConfig: SupabaseConfig? {
        if let configuredURL = bundleString("SunnadSupabaseURL"),
           let url = URL(string: configuredURL),
           let anonKey = bundleString("SunnadSupabaseAnonKey"),
           !anonKey.isEmpty {
            return SupabaseConfig(url: url, anonKey: anonKey)
        }

        if let rawURL = debugResolveEnv(["SUNNAD_SUPABASE_URL", "SUPABASE_URL"]),
           let url = URL(string: rawURL),
           let anonKey = debugResolveEnv([
               "SUNNAD_SUPABASE_ANON_KEY",
               "SUPABASE_ANON_KEY",
               "SUNNAD_SUPABASE_PUBLISHABLE_KEY",
               "SUPABASE_PUBLISHABLE_KEY"
           ]) {
            return SupabaseConfig(url: url, anonKey: anonKey)
        }

        #if DEBUG
        // Local fallback is explicit opt-in only to avoid silently masking bad hosted env config.
        // This key is the default local Supabase anon key generated by CLI projects.
        let fallbackKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
        let fallbackPorts = [55421, 54321]
        if debugResolveEnv(["SUNNAD_ENABLE_LOCAL_SUPABASE_FALLBACK"]) == "1" {
            for port in fallbackPorts {
                if let url = URL(string: "http://127.0.0.1:\(port)") {
                    return SupabaseConfig(url: url, anonKey: fallbackKey)
                }
            }
        }
        #endif

        return nil
    }

    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }

    private func resolveBoolEnvOptional(_ key: String) -> Bool? {
        guard let raw = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }

        switch raw.lowercased() {
        case "1", "true", "yes":
            return true
        case "0", "false", "no":
            return false
        default:
            return nil
        }
    }

    private func bundleString(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        return normalized.isEmpty ? nil : normalized
    }

    private func bundleBool(_ key: String) -> Bool? {
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? Bool {
            return value
        }
        if let raw = bundleString(key) {
            switch raw.lowercased() {
            case "1", "true", "yes":
                return true
            case "0", "false", "no":
                return false
            default:
                return nil
            }
        }
        return nil
    }

    private func bundleInt(_ key: String) -> Int? {
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? Int {
            return value
        }
        if let raw = bundleString(key) {
            return Int(raw)
        }
        return nil
    }

    private func resolveEnv(_ names: [String]) -> String? {
        for name in names {
            guard let rawValue = ProcessInfo.processInfo.environment[name] else {
                continue
            }

            let normalized = rawValue
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty } ?? rawValue

            let trimmed = normalized
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return nil
    }

    private func debugResolveEnv(_ names: [String]) -> String? {
        #if DEBUG
        return resolveEnv(names)
        #else
        return nil
        #endif
    }

    private func debugResolveBoolEnvOptional(_ key: String) -> Bool? {
        #if DEBUG
        return resolveBoolEnvOptional(key)
        #else
        return nil
        #endif
    }
}
