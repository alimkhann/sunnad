import Foundation

struct SessionUser: Equatable, Sendable {
    let id: UUID
    let email: String?
    let username: String?

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
