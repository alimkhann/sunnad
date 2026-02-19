import Combine
import Foundation

enum AppEnvironment: String {
    case development
    case production

    var publicAppLink: URL {
        if let override = ProcessInfo.processInfo.environment["SUNNAD_PUBLIC_APP_LINK"],
           let url = URL(string: override), !override.isEmpty {
            return url
        }

        return URL(string: "https://www.sunnad.app")!
    }

    var privacyURL: URL {
        URL(string: "https://www.sunnad.app/privacy")!
    }

    var helpURL: URL {
        URL(string: "https://www.sunnad.app/help")!
    }

    struct SupabaseConfig {
        let url: URL
        let anonKey: String
    }

    var supabaseConfig: SupabaseConfig? {
        guard
            let rawURL = ProcessInfo.processInfo.environment["SUNNAD_SUPABASE_URL"],
            let url = URL(string: rawURL),
            !rawURL.isEmpty,
            let anonKey = ProcessInfo.processInfo.environment["SUNNAD_SUPABASE_ANON_KEY"],
            !anonKey.isEmpty
        else {
            return nil
        }

        return SupabaseConfig(url: url, anonKey: anonKey)
    }

    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
}
