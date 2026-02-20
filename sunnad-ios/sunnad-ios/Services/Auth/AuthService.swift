import Foundation

enum AuthServiceError: Error, LocalizedError {
    case unavailable
    case invalidCredentials
    case invalidRecoveryLink
    case emailAlreadyInUse
    case usernameAlreadyInUse
    case weakPassword
    case emailNotConfirmed
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Authentication is not configured."
        case .invalidCredentials:
            return "Invalid email/username or password."
        case .invalidRecoveryLink:
            return "Password recovery link is invalid or expired."
        case .emailAlreadyInUse:
            return "An account with this email already exists."
        case .usernameAlreadyInUse:
            return "This username is already taken."
        case .weakPassword:
            return "Password is too weak. Use at least 8 characters with mixed character types."
        case .emailNotConfirmed:
            return "Please verify your email before signing in."
        case .unknown(let message):
            return message
        }
    }
}

protocol AuthService: Sendable {
    func signUp(email: String, password: String, username: String?) async throws -> SessionUser
    func signIn(identifier: String, password: String) async throws -> SessionUser
    func signOut() async throws
    func deleteAccount() async throws
    func requestPasswordReset(email: String, redirectTo: URL?) async throws
    func updatePassword(newPassword: String) async throws -> SessionUser
    func handleAuthCallback(url: URL) async throws -> SessionUser?
    func currentUser() async -> SessionUser?
}

protocol DeviceTokenSyncing: Sendable {
    func syncCurrentDeviceToken(for userID: UUID) async
}

struct UnconfiguredAuthService: AuthService {
    func signUp(email: String, password: String, username: String?) async throws -> SessionUser {
        throw AuthServiceError.unavailable
    }

    func signIn(identifier: String, password: String) async throws -> SessionUser {
        throw AuthServiceError.unavailable
    }

    func signOut() async throws {}

    func deleteAccount() async throws {
        throw AuthServiceError.unavailable
    }

    func requestPasswordReset(email: String, redirectTo: URL?) async throws {
        throw AuthServiceError.unavailable
    }

    func updatePassword(newPassword: String) async throws -> SessionUser {
        throw AuthServiceError.unavailable
    }

    func handleAuthCallback(url: URL) async throws -> SessionUser? {
        throw AuthServiceError.unavailable
    }

    func currentUser() async -> SessionUser? {
        nil
    }
}

struct NoOpDeviceTokenSyncService: DeviceTokenSyncing {
    func syncCurrentDeviceToken(for userID: UUID) async {}
}
