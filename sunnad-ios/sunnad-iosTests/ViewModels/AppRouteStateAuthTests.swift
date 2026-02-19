import Foundation
import Testing
@testable import sunnad_ios

@MainActor
struct AppRouteStateAuthTests {
    @Test
    func restoresExistingSessionOnInit() async throws {
        let sessionUser = SessionUser(id: UUID(), email: "restore@example.com", username: "RestoreUser")
        let authService = FakeAuthService(currentUserValue: sessionUser)
        let tokenSync = FakeDeviceTokenSyncService()

        let dependencies = DependencyContainer(
            modelContainer: try makeInMemoryContainer(),
            authService: authService,
            deviceTokenSyncService: tokenSync
        )

        let state = AppRouteState(dependencies: dependencies)
        _ = await waitUntil(timeoutNanoseconds: 2_000_000_000) {
            !state.user.isGuest
        }

        #expect(state.user.isGuest == false)
        #expect(state.user.email == "restore@example.com")
        #expect(tokenSync.syncedUserIDs.contains(sessionUser.id))
    }

    @Test
    func signInAndSignOutTransitionsBetweenMemberAndGuest() async throws {
        let signInUser = SessionUser(id: UUID(), email: "signin@example.com", username: "SignInUser")
        let authService = FakeAuthService(currentUserValue: nil, signInValue: signInUser)
        let tokenSync = FakeDeviceTokenSyncService()

        let dependencies = DependencyContainer(
            modelContainer: try makeInMemoryContainer(),
            authService: authService,
            deviceTokenSyncService: tokenSync
        )

        let state = AppRouteState(dependencies: dependencies)

        state.handleSignIn(username: "signin@example.com", password: "password")
        _ = await waitUntil(timeoutNanoseconds: 2_000_000_000) {
            state.user.email == "signin@example.com"
        }

        #expect(state.user.isGuest == false)
        #expect(state.user.email == "signin@example.com")
        #expect(tokenSync.syncedUserIDs.contains(signInUser.id))

        state.signOut()
        _ = await waitUntil(timeoutNanoseconds: 2_000_000_000) {
            state.user.isGuest
        }

        #expect(state.user.isGuest)
        #expect(authService.signOutCalled)
    }

    private func waitUntil(timeoutNanoseconds: UInt64, condition: @escaping @MainActor () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutNanoseconds) / 1_000_000_000)
        while Date() < deadline {
            if condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return condition()
    }
}

final class FakeAuthService: AuthService, @unchecked Sendable {
    var currentUserValue: SessionUser?
    var signInValue: SessionUser
    var signOutCalled = false

    init(
        currentUserValue: SessionUser?,
        signInValue: SessionUser = SessionUser(id: UUID(), email: "user@example.com", username: "User")
    ) {
        self.currentUserValue = currentUserValue
        self.signInValue = signInValue
    }

    func signUp(email: String, password: String, username: String?) async throws -> SessionUser {
        SessionUser(id: UUID(), email: email, username: username)
    }

    func signIn(email: String, password: String) async throws -> SessionUser {
        SessionUser(id: signInValue.id, email: email, username: signInValue.username)
    }

    func signOut() async throws {
        signOutCalled = true
        currentUserValue = nil
    }

    func currentUser() async -> SessionUser? {
        currentUserValue
    }
}

final class FakeDeviceTokenSyncService: DeviceTokenSyncing, @unchecked Sendable {
    private(set) var syncedUserIDs: [UUID] = []

    func syncCurrentDeviceToken(for userID: UUID) async {
        syncedUserIDs.append(userID)
    }
}
