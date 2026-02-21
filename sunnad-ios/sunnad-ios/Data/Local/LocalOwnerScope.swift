import Foundation

enum LocalOwnerScope: Equatable {
    case guest
    case user(UUID)

    var rawValue: String {
        switch self {
        case .guest:
            return "guest"
        case .user(let userID):
            return "user:\(userID.uuidString.lowercased())"
        }
    }
}

@MainActor
protocol LocalOwnerScopeProviding: AnyObject {
    var currentOwnerScope: LocalOwnerScope { get }
    var currentOwnerScopeRawValue: String { get }
    func setSignedInUserID(_ userID: UUID?)
}

@MainActor
final class LocalOwnerScopeResolver: LocalOwnerScopeProviding {
    private enum Keys {
        static let scopePrefix = "sunnad.local.owner_scope"
    }

    private let storageKey: String
    private let userDefaults: UserDefaults

    private(set) var currentOwnerScope: LocalOwnerScope

    var currentOwnerScopeRawValue: String {
        currentOwnerScope.rawValue
    }

    init(namespace: String, userDefaults: UserDefaults = .standard) {
        self.storageKey = "\(Keys.scopePrefix).\(namespace)"
        self.userDefaults = userDefaults

        if let persisted = userDefaults.string(forKey: storageKey),
           let restored = Self.scope(from: persisted) {
            currentOwnerScope = restored
        } else {
            currentOwnerScope = .guest
            userDefaults.set(currentOwnerScope.rawValue, forKey: storageKey)
        }
    }

    func setSignedInUserID(_ userID: UUID?) {
        if let userID {
            currentOwnerScope = .user(userID)
        } else {
            currentOwnerScope = .guest
        }
        userDefaults.set(currentOwnerScope.rawValue, forKey: storageKey)
    }

    private static func scope(from raw: String) -> LocalOwnerScope? {
        if raw == "guest" {
            return .guest
        }
        if raw.hasPrefix("user:") {
            let value = String(raw.dropFirst("user:".count))
            if let userID = UUID(uuidString: value) {
                return .user(userID)
            }
        }
        return nil
    }
}
