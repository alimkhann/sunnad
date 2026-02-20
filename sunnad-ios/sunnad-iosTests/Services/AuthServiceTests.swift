import Foundation
import Testing
@testable import sunnad_ios

struct AuthServiceTests {
    @Test
    func unconfiguredAuthServiceThrowsUnavailable() async {
        let service = await UnconfiguredAuthService()

        await #expect(throws: AuthServiceError.self) {
            _ = try await service.signIn(identifier: "user@example.com", password: "password")
        }

        await #expect(throws: AuthServiceError.self) {
            _ = try await service.signInWithGoogle()
        }

        await #expect(throws: AuthServiceError.self) {
            _ = try await service.signInWithApple()
        }

        await #expect(throws: AuthServiceError.self) {
            try await service.deleteAccount()
        }

        await #expect(throws: AuthServiceError.self) {
            _ = try await service.fetchProfile()
        }

        await #expect(throws: AuthServiceError.self) {
            _ = try await service.updateUsername("user_01")
        }

        await #expect(throws: AuthServiceError.self) {
            _ = try await service.uploadAvatar(data: Data(), mimeType: "image/jpeg")
        }

        await #expect(throws: AuthServiceError.self) {
            _ = try await service.removeAvatar()
        }

        await #expect(throws: AuthServiceError.self) {
            try await service.requestPasswordReset(email: "user@example.com", redirectTo: nil)
        }

        await #expect(throws: AuthServiceError.self) {
            _ = try await service.verifyEmailOTP(email: "user@example.com", code: "123456")
        }

        await #expect(throws: AuthServiceError.self) {
            _ = try await service.verifyRecoveryCode(email: "user@example.com", code: "123456")
        }

        await #expect(throws: AuthServiceError.self) {
            try await service.resendSignUpOTP(email: "user@example.com", redirectTo: nil)
        }

        await #expect(throws: AuthServiceError.self) {
            try await service.resendRecoveryCode(email: "user@example.com", redirectTo: nil)
        }

        await #expect(throws: AuthServiceError.self) {
            _ = try await service.updatePassword(newPassword: "NewPassword123!")
        }

        await #expect(throws: AuthServiceError.self) {
            _ = try await service.handleAuthCallback(url: URL(string: "sunnad://auth-callback")!)
        }

        let currentUser = await service.currentUser()
        #expect(currentUser == nil)
    }

    @Test
    func noOpDeviceTokenSyncServiceIsSafe() async {
        let service = await NoOpDeviceTokenSyncService()
        await service.syncCurrentDeviceToken(for: UUID())
    }

    @Test
    func sessionUserDisplayNamePrefersUsernameThenEmail() {
        let withUsername = SessionUser(id: UUID(), email: "user@example.com", username: "Ali")
        #expect(withUsername.displayName == "Ali")

        let withEmail = SessionUser(id: UUID(), email: "user@example.com", username: nil)
        #expect(withEmail.displayName == "user@example.com")
    }
}
