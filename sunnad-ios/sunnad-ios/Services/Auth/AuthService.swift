import Foundation

enum AuthServiceError: Error, LocalizedError {
    case unavailable
    case invalidCredentials
    case invalidRecoveryLink
    case invalidOTPCode
    case invalidUsername
    case emailAlreadyInUse
    case usernameAlreadyInUse
    case weakPassword
    case emailNotConfirmed
    case rateLimited
    case providerUnavailable(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Authentication is not configured."
        case .invalidCredentials:
            return "Invalid email/username or password."
        case .invalidRecoveryLink:
            return "Password recovery link is invalid or expired."
        case .invalidOTPCode:
            return "Verification code is invalid or expired."
        case .invalidUsername:
            return "Username must be 3-20 characters and use only lowercase letters, numbers, or underscores."
        case .emailAlreadyInUse:
            return "An account with this email already exists."
        case .usernameAlreadyInUse:
            return "This username is already taken."
        case .weakPassword:
            return "Password is too weak. Use at least 8 characters with mixed character types."
        case .emailNotConfirmed:
            return "Please verify your email before signing in."
        case .rateLimited:
            return "Too many attempts. Please wait and try again."
        case .providerUnavailable(let provider):
            return "\(provider) sign in is not available yet."
        case .unknown(let message):
            return message
        }
    }
}

protocol AuthService: Sendable {
    func signUp(email: String, password: String, username: String?) async throws -> SessionUser
    func signIn(identifier: String, password: String) async throws -> SessionUser
    func signInWithGoogle() async throws -> SessionUser
    func signInWithApple() async throws -> SessionUser
    func verifyEmailOTP(email: String, code: String) async throws -> SessionUser
    func verifyRecoveryCode(email: String, code: String) async throws -> SessionUser
    func resendSignUpOTP(email: String, redirectTo: URL?) async throws
    func resendRecoveryCode(email: String, redirectTo: URL?) async throws
    func signOut() async throws
    func deleteAccount() async throws
    func fetchProfile() async throws -> SessionUser
    func updateUsername(_ username: String) async throws -> SessionUser
    func uploadAvatar(data: Data, mimeType: String) async throws -> SessionUser
    func removeAvatar() async throws -> SessionUser
    func requestPasswordReset(email: String, redirectTo: URL?) async throws
    func updatePassword(newPassword: String) async throws -> SessionUser
    func handleAuthCallback(url: URL) async throws -> SessionUser?
    func currentUser() async -> SessionUser?
    func currentAccessToken() async -> String?
}

extension AuthService {
    func currentAccessToken() async -> String? { nil }
}

protocol DeviceTokenSyncing: Sendable {
    func syncCurrentDeviceToken(for userID: UUID) async
    func setGroupRemindersEnabled(_ enabled: Bool, for userID: UUID) async
    func syncProfileContext(for userID: UUID, locale: String, timeZone: String) async
    func removeCurrentInstallation(for userID: UUID) async
}

extension DeviceTokenSyncing {
    func syncProfileContext(for userID: UUID, locale: String, timeZone: String) async {
        _ = (userID, locale, timeZone)
    }

    func removeCurrentInstallation(for userID: UUID) async {
        _ = userID
    }
}

struct UnconfiguredAuthService: AuthService {
    func signUp(email: String, password: String, username: String?) async throws -> SessionUser {
        throw AuthServiceError.unavailable
    }

    func signIn(identifier: String, password: String) async throws -> SessionUser {
        throw AuthServiceError.unavailable
    }

    func signInWithGoogle() async throws -> SessionUser {
        throw AuthServiceError.unavailable
    }

    func signInWithApple() async throws -> SessionUser {
        throw AuthServiceError.unavailable
    }

    func verifyEmailOTP(email: String, code: String) async throws -> SessionUser {
        throw AuthServiceError.unavailable
    }

    func verifyRecoveryCode(email: String, code: String) async throws -> SessionUser {
        throw AuthServiceError.unavailable
    }

    func resendSignUpOTP(email: String, redirectTo: URL?) async throws {
        throw AuthServiceError.unavailable
    }

    func resendRecoveryCode(email: String, redirectTo: URL?) async throws {
        throw AuthServiceError.unavailable
    }

    func signOut() async throws {}

    func deleteAccount() async throws {
        throw AuthServiceError.unavailable
    }

    func fetchProfile() async throws -> SessionUser {
        throw AuthServiceError.unavailable
    }

    func updateUsername(_ username: String) async throws -> SessionUser {
        throw AuthServiceError.unavailable
    }

    func uploadAvatar(data: Data, mimeType: String) async throws -> SessionUser {
        throw AuthServiceError.unavailable
    }

    func removeAvatar() async throws -> SessionUser {
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
    func setGroupRemindersEnabled(_ enabled: Bool, for userID: UUID) async {}
}
