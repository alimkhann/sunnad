import Foundation

enum AuthProvider: String, Equatable, Sendable {
    case email
    case google
    case apple
    case unknown
}

struct SessionUser: Equatable, Sendable {
    let id: UUID
    let email: String?
    let username: String?
    let avatarURL: URL?
    let provider: AuthProvider

    init(
        id: UUID,
        email: String?,
        username: String?,
        avatarURL: URL? = nil,
        provider: AuthProvider = .unknown
    ) {
        self.id = id
        self.email = email
        self.username = username
        self.avatarURL = avatarURL
        self.provider = provider
    }

    var displayName: String {
        if let username, !username.isEmpty {
            return username
        }

        if let email, !email.isEmpty {
            return email
        }

        return "User"
    }
}
