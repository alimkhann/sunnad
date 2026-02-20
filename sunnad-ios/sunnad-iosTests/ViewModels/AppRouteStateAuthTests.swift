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
        _ = await waitUntil(timeoutNanoseconds: 5_000_000_000) {
            !state.user.isGuest
        }

        #expect(state.user.isGuest == false)
        #expect(state.user.email == "restore@example.com")
        #expect(await tokenSync.containsSyncedUserID(sessionUser.id))
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

        state.handleSignIn(identifier: "signin@example.com", password: "password")
        _ = await waitUntil(timeoutNanoseconds: 5_000_000_000) {
            state.user.email == "signin@example.com"
        }

        #expect(state.user.isGuest == false)
        #expect(state.user.email == "signin@example.com")
        #expect(await tokenSync.containsSyncedUserID(signInUser.id))

        state.signOut()
        _ = await waitUntil(timeoutNanoseconds: 5_000_000_000) {
            state.user.isGuest
        }

        #expect(state.user.isGuest)
        #expect(await authService.didCallSignOut())
    }

    @Test
    func onboardingSignUpRequiresOTPThenVerifySignsIn() async throws {
        let verifiedUser = SessionUser(id: UUID(), email: "otp@example.com", username: "OtpUser")
        let authService = FakeAuthService(
            currentUserValue: nil,
            signUpRequiresEmailConfirmation: true,
            otpVerifiedUser: verifiedUser
        )
        let tokenSync = FakeDeviceTokenSyncService()
        let dependencies = DependencyContainer(
            modelContainer: try makeInMemoryContainer(),
            authService: authService,
            deviceTokenSyncService: tokenSync
        )
        let state = AppRouteState(dependencies: dependencies)

        state.handleSignUp(
            email: "otp@example.com",
            username: "OtpUser",
            password: "StrongPass123!",
            method: "email"
        )

        _ = await waitUntil(timeoutNanoseconds: 5_000_000_000) {
            state.onboardingStep == .otp
        }

        #expect(state.onboardingStep == .otp)
        #expect(state.authSuccessMessage == L10n.t("auth.otp.sent"))

        state.verifyOTP(code: "123456")

        _ = await waitUntil(timeoutNanoseconds: 5_000_000_000) {
            state.user.email == "otp@example.com" && state.activeTab == .today
        }

        #expect(state.user.email == "otp@example.com")
        #expect(await authService.recordedOTPVerificationEmail() == "otp@example.com")
        #expect(await authService.recordedOTPVerificationCode() == "123456")
        #expect(await tokenSync.containsSyncedUserID(verifiedUser.id))
    }

    @Test
    func resendOTPUsesPendingEmailAndPublishesSuccess() async throws {
        let authService = FakeAuthService(currentUserValue: nil)
        let dependencies = DependencyContainer(
            modelContainer: try makeInMemoryContainer(),
            authService: authService,
            deviceTokenSyncService: FakeDeviceTokenSyncService()
        )
        let state = AppRouteState(dependencies: dependencies)

        state.pendingSignUpEmail = "otp@example.com"
        state.resendOTP()

        _ = await waitUntil(timeoutNanoseconds: 5_000_000_000) {
            state.authSuccessMessage == L10n.t("auth.otp.resent")
        }

        #expect(await authService.recordedResendOTPEmail() == "otp@example.com")
        #expect(await authService.recordedResendOTPRedirect() != nil)
    }

    @Test
    func deleteAccountTransitionsToGuestWithoutOnboarding() async throws {
        let signInUser = SessionUser(id: UUID(), email: "delete@example.com", username: "DeleteUser")
        let authService = FakeAuthService(currentUserValue: nil, signInValue: signInUser)
        let dependencies = DependencyContainer(
            modelContainer: try makeInMemoryContainer(),
            authService: authService,
            deviceTokenSyncService: FakeDeviceTokenSyncService()
        )
        let state = AppRouteState(dependencies: dependencies)

        state.handleSignIn(identifier: "delete@example.com", password: "password")
        _ = await waitUntil(timeoutNanoseconds: 5_000_000_000) {
            state.user.isGuest == false
        }

        state.deleteAccount()
        _ = await waitUntil(timeoutNanoseconds: 5_000_000_000) {
            state.user.isGuest && state.activeTab == .profile
        }

        #expect(state.user.isGuest)
        #expect(state.showsOnboarding == false)
        #expect(state.activeTab == .profile)
        #expect(await authService.didCallDeleteAccount())
    }

    @Test
    func passwordResetRequestPublishesSuccessMessage() async throws {
        let authService = FakeAuthService(currentUserValue: nil)
        let dependencies = DependencyContainer(
            modelContainer: try makeInMemoryContainer(),
            authService: authService,
            deviceTokenSyncService: FakeDeviceTokenSyncService()
        )
        let state = AppRouteState(dependencies: dependencies)

        state.submitPasswordResetRequest(email: "reset@example.com")

        _ = await waitUntil(timeoutNanoseconds: 5_000_000_000) {
            state.authSuccessMessage == L10n.t("auth.forgot_password.sent")
        }

        #expect(await authService.recordedPasswordResetEmail() == "reset@example.com")
        #expect(await authService.recordedPasswordResetRedirect() != nil)
        #expect(state.authErrorMessage == nil)
        #expect(state.authSuccessMessage == L10n.t("auth.forgot_password.sent"))
    }

    @Test
    func recoveryCallbackOpensChangePasswordFlow() async throws {
        let callbackUser = SessionUser(id: UUID(), email: "recover@example.com", username: "RecoverUser")
        let authService = FakeAuthService(currentUserValue: nil, callbackUser: callbackUser)
        let tokenSync = FakeDeviceTokenSyncService()
        let dependencies = DependencyContainer(
            modelContainer: try makeInMemoryContainer(),
            authService: authService,
            deviceTokenSyncService: tokenSync
        )
        let state = AppRouteState(dependencies: dependencies)
        let callbackURL = URL(string: "sunnad://auth-callback#access_token=fake&type=recovery")!

        state.handleIncomingURL(callbackURL)
        _ = await waitUntil(timeoutNanoseconds: 5_000_000_000) {
            state.fullScreen == .changePassword && state.user.email == "recover@example.com"
        }

        #expect(state.fullScreen == .changePassword)
        #expect(state.user.email == "recover@example.com")
        #expect(await tokenSync.containsSyncedUserID(callbackUser.id))
    }

    @Test
    func recoveryCallbackWithPKCECodeOpensChangePasswordFlow() async throws {
        let callbackUser = SessionUser(id: UUID(), email: "recover-code@example.com", username: "RecoverCodeUser")
        let authService = FakeAuthService(currentUserValue: nil, callbackUser: callbackUser)
        let tokenSync = FakeDeviceTokenSyncService()
        let dependencies = DependencyContainer(
            modelContainer: try makeInMemoryContainer(),
            authService: authService,
            deviceTokenSyncService: tokenSync
        )
        let state = AppRouteState(dependencies: dependencies)
        let callbackURL = URL(string: "sunnad://auth-callback?code=fakepkcecode&type=recovery")!

        state.handleIncomingURL(callbackURL)
        _ = await waitUntil(timeoutNanoseconds: 5_000_000_000) {
            state.fullScreen == .changePassword && state.user.email == "recover-code@example.com"
        }

        #expect(state.fullScreen == .changePassword)
        #expect(state.user.email == "recover-code@example.com")
        #expect(await tokenSync.containsSyncedUserID(callbackUser.id))
    }

    @Test
    func pendingRecoveryWithCodeOnlyCallbackOpensChangePasswordFlow() async throws {
        let callbackUser = SessionUser(id: UUID(), email: "recover-pending@example.com", username: "RecoverPendingUser")
        let authService = FakeAuthService(currentUserValue: nil, callbackUser: callbackUser)
        let tokenSync = FakeDeviceTokenSyncService()
        let defaults = makeIsolatedUserDefaults()
        let dependencies = DependencyContainer(
            modelContainer: try makeInMemoryContainer(),
            authService: authService,
            deviceTokenSyncService: tokenSync
        )
        let state = AppRouteState(dependencies: dependencies, userDefaults: defaults)

        state.submitPasswordResetRequest(email: "recover-pending@example.com")
        _ = await waitUntil(timeoutNanoseconds: 5_000_000_000) {
            state.authSuccessMessage == L10n.t("auth.forgot_password.sent")
        }

        let callbackURL = URL(string: "sunnad://auth-callback?code=fakepkcecodeonly")!
        state.handleIncomingURL(callbackURL)

        _ = await waitUntil(timeoutNanoseconds: 5_000_000_000) {
            state.fullScreen == .changePassword && state.user.email == "recover-pending@example.com"
        }

        #expect(state.fullScreen == .changePassword)
        #expect(state.user.email == "recover-pending@example.com")
        #expect(await tokenSync.containsSyncedUserID(callbackUser.id))
    }

    @Test
    func pendingRecoveryWithBareCallbackURLStillOpensChangePasswordFlow() async throws {
        let callbackUser = SessionUser(id: UUID(), email: "recover-bare@example.com", username: "RecoverBareUser")
        let authService = FakeAuthService(currentUserValue: nil, callbackUser: callbackUser)
        let tokenSync = FakeDeviceTokenSyncService()
        let defaults = makeIsolatedUserDefaults()
        let dependencies = DependencyContainer(
            modelContainer: try makeInMemoryContainer(),
            authService: authService,
            deviceTokenSyncService: tokenSync
        )
        let state = AppRouteState(dependencies: dependencies, userDefaults: defaults)

        state.submitPasswordResetRequest(email: "recover-bare@example.com")
        _ = await waitUntil(timeoutNanoseconds: 5_000_000_000) {
            state.authSuccessMessage == L10n.t("auth.forgot_password.sent")
        }

        let callbackURL = URL(string: "sunnad://auth-callback")!
        state.handleIncomingURL(callbackURL)

        _ = await waitUntil(timeoutNanoseconds: 5_000_000_000) {
            state.fullScreen == .changePassword && state.user.email == "recover-bare@example.com"
        }

        #expect(state.fullScreen == .changePassword)
        #expect(state.user.email == "recover-bare@example.com")
        #expect(await tokenSync.containsSyncedUserID(callbackUser.id))
    }

    @Test
    func changePasswordUpdatesSessionAndClosesModal() async throws {
        let initialUser = SessionUser(id: UUID(), email: "before@example.com", username: "Before")
        let changedUser = SessionUser(id: initialUser.id, email: "after@example.com", username: "After")
        let authService = FakeAuthService(
            currentUserValue: initialUser,
            signInValue: initialUser,
            passwordUpdateValue: changedUser
        )
        let dependencies = DependencyContainer(
            modelContainer: try makeInMemoryContainer(),
            authService: authService,
            deviceTokenSyncService: FakeDeviceTokenSyncService()
        )
        let state = AppRouteState(dependencies: dependencies)
        _ = await waitUntil(timeoutNanoseconds: 5_000_000_000) {
            state.user.isGuest == false
        }

        state.openChangePassword()
        state.submitChangePassword(newPassword: "StrongPass123!")

        _ = await waitUntil(timeoutNanoseconds: 5_000_000_000) {
            state.fullScreen == nil && state.user.name == "After"
        }

        #expect(await authService.recordedUpdatedPassword() == "StrongPass123!")
        #expect(state.fullScreen == nil)
        #expect(state.user.name == "After")
        #expect(state.authSuccessMessage == L10n.t("auth.change_password.updated"))
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

    private func makeIsolatedUserDefaults() -> UserDefaults {
        let suite = "sunnad.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}

actor FakeAuthService: AuthService {
    var currentUserValue: SessionUser?
    var signInValue: SessionUser
    var signUpRequiresEmailConfirmation: Bool
    var otpVerifiedUser: SessionUser
    var callbackUser: SessionUser?
    var passwordUpdateValue: SessionUser
    var signOutCalled = false
    var deleteAccountCalled = false
    var lastPasswordResetEmail: String?
    var lastPasswordResetRedirect: URL?
    var lastUpdatedPassword: String?
    var lastOTPEmail: String?
    var lastOTPCode: String?
    var lastResendOTPEmail: String?
    var lastResendOTPRedirect: URL?

    init(
        currentUserValue: SessionUser?,
        signInValue: SessionUser = SessionUser(id: UUID(), email: "user@example.com", username: "User"),
        signUpRequiresEmailConfirmation: Bool = false,
        otpVerifiedUser: SessionUser? = nil,
        callbackUser: SessionUser? = nil,
        passwordUpdateValue: SessionUser? = nil
    ) {
        self.currentUserValue = currentUserValue
        self.signInValue = signInValue
        self.signUpRequiresEmailConfirmation = signUpRequiresEmailConfirmation
        self.otpVerifiedUser = otpVerifiedUser ?? signInValue
        self.callbackUser = callbackUser
        self.passwordUpdateValue = passwordUpdateValue ?? signInValue
    }

    func signUp(email: String, password: String, username: String?) async throws -> SessionUser {
        if signUpRequiresEmailConfirmation {
            throw AuthServiceError.emailNotConfirmed
        }
        let sessionUser = SessionUser(id: UUID(), email: email, username: username)
        currentUserValue = sessionUser
        return sessionUser
    }

    func signIn(identifier: String, password: String) async throws -> SessionUser {
        let user = signInValue
        return SessionUser(id: user.id, email: identifier, username: user.username)
    }

    func verifyEmailOTP(email: String, code: String) async throws -> SessionUser {
        lastOTPEmail = email
        lastOTPCode = code
        currentUserValue = otpVerifiedUser
        return otpVerifiedUser
    }

    func resendSignUpOTP(email: String, redirectTo: URL?) async throws {
        lastResendOTPEmail = email
        lastResendOTPRedirect = redirectTo
    }

    func signOut() async throws {
        signOutCalled = true
        currentUserValue = nil
    }

    func deleteAccount() async throws {
        deleteAccountCalled = true
        currentUserValue = nil
    }

    func requestPasswordReset(email: String, redirectTo: URL?) async throws {
        lastPasswordResetEmail = email
        lastPasswordResetRedirect = redirectTo
    }

    func updatePassword(newPassword: String) async throws -> SessionUser {
        lastUpdatedPassword = newPassword
        currentUserValue = passwordUpdateValue
        return passwordUpdateValue
    }

    func handleAuthCallback(url: URL) async throws -> SessionUser? {
        currentUserValue = callbackUser
        return callbackUser
    }

    func currentUser() async -> SessionUser? {
        currentUserValue
    }

    func didCallSignOut() -> Bool {
        signOutCalled
    }

    func didCallDeleteAccount() -> Bool {
        deleteAccountCalled
    }

    func recordedPasswordResetEmail() -> String? {
        lastPasswordResetEmail
    }

    func recordedPasswordResetRedirect() -> URL? {
        lastPasswordResetRedirect
    }

    func recordedUpdatedPassword() -> String? {
        lastUpdatedPassword
    }

    func recordedOTPVerificationEmail() -> String? {
        lastOTPEmail
    }

    func recordedOTPVerificationCode() -> String? {
        lastOTPCode
    }

    func recordedResendOTPEmail() -> String? {
        lastResendOTPEmail
    }

    func recordedResendOTPRedirect() -> URL? {
        lastResendOTPRedirect
    }
}

actor FakeDeviceTokenSyncService: DeviceTokenSyncing {
    private(set) var syncedUserIDs: [UUID] = []

    func syncCurrentDeviceToken(for userID: UUID) async {
        syncedUserIDs.append(userID)
    }

    func containsSyncedUserID(_ userID: UUID) -> Bool {
        syncedUserIDs.contains(userID)
    }
}
