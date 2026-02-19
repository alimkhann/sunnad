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

    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
}
