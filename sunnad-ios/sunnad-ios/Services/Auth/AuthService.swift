import Foundation

enum AuthServiceError: Error, LocalizedError {
    case unavailable
    case invalidCredentials
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Authentication is not configured."
        case .invalidCredentials:
            return "Invalid email or password."
        case .unknown(let message):
            return message
        }
    }
}

protocol AuthService: Sendable {
    func signUp(email: String, password: String, username: String?) async throws -> SessionUser
    func signIn(email: String, password: String) async throws -> SessionUser
    func signOut() async throws
    func currentUser() async -> SessionUser?
}

protocol DeviceTokenSyncing: Sendable {
    func syncCurrentDeviceToken(for userID: UUID) async
}

struct UnconfiguredAuthService: AuthService {
    func signUp(email: String, password: String, username: String?) async throws -> SessionUser {
        throw AuthServiceError.unavailable
    }

    func signIn(email: String, password: String) async throws -> SessionUser {
        throw AuthServiceError.unavailable
    }

    func signOut() async throws {}

    func currentUser() async -> SessionUser? {
        nil
    }
}

struct NoOpDeviceTokenSyncService: DeviceTokenSyncing {
    func syncCurrentDeviceToken(for userID: UUID) async {}
}
