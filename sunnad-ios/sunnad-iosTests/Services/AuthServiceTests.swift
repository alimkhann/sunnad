import Foundation
import Testing
@testable import sunnad_ios

struct AuthServiceTests {
    @Test
    func unconfiguredAuthServiceThrowsUnavailable() async {
        let service = await UnconfiguredAuthService()

        await #expect(throws: AuthServiceError.self) {
            _ = try await service.signIn(email: "user@example.com", password: "password")
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
