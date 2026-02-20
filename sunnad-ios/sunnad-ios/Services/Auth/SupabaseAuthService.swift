import Foundation
import Supabase

final class SupabaseAuthService: AuthService, @unchecked Sendable {
    private struct ProfileUsernameRow: Decodable {
        let username: String?
    }

    private struct DeleteAccountResponse: Decodable {
        let ok: Bool?
    }

    private let client: SupabaseClient
    private let supabaseURL: URL
    private let authRedirectURL: URL?

    init(client: SupabaseClient, supabaseURL: URL, authRedirectURL: URL?) {
        self.client = client
        self.supabaseURL = supabaseURL
        self.authRedirectURL = authRedirectURL
    }

    func signUp(email: String, password: String, username: String?) async throws -> SessionUser {
        do {
            let cleanedUsername = sanitizeUsername(username)
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: cleanedUsername.flatMap { value in
                    ["username": AnyJSON.string(value)]
                },
                redirectTo: authRedirectURL
            )

            if let session = response.session {
                if let cleanedUsername {
                    try? await persistProfileUsername(cleanedUsername, for: session.user.id)
                }
                return await sessionUser(from: session.user, fallbackUsername: cleanedUsername)
            }

            if let cleanedUsername {
                try? await persistProfileUsername(cleanedUsername, for: response.user.id)
            }
            throw AuthServiceError.emailNotConfirmed
        } catch {
            if let mapped = error as? AuthServiceError {
                throw mapped
            }
            throw mapAuthError(error)
        }
    }

    func signIn(identifier: String, password: String) async throws -> SessionUser {
        do {
            let resolvedEmail = await resolveSignInEmail(identifier: identifier)
            let session = try await client.auth.signIn(email: resolvedEmail, password: password)
            return await sessionUser(from: session.user)
        } catch {
            throw mapAuthError(error)
        }
    }

    func signInWithGoogle() async throws -> SessionUser {
        do {
            let session = try await client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: authRedirectURL
            )
            return await sessionUser(from: session.user)
        } catch {
            throw mapAuthError(error)
        }
    }

    func signInWithApple() async throws -> SessionUser {
        throw AuthServiceError.providerUnavailable("Apple")
    }

    func verifyEmailOTP(email: String, code: String) async throws -> SessionUser {
        do {
            let response = try await client.auth.verifyOTP(
                email: email,
                token: code,
                type: .signup,
                redirectTo: authRedirectURL
            )
            return await sessionUser(from: response.user)
        } catch {
            throw mapAuthError(error)
        }
    }

    func verifyRecoveryCode(email: String, code: String) async throws -> SessionUser {
        do {
            let response = try await client.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery,
                redirectTo: authRedirectURL
            )
            return await sessionUser(from: response.user)
        } catch {
            throw mapAuthError(error)
        }
    }

    func resendSignUpOTP(email: String, redirectTo: URL?) async throws {
        do {
            try await client.auth.resend(
                email: email,
                type: .signup,
                emailRedirectTo: redirectTo ?? authRedirectURL
            )
        } catch {
            throw mapAuthError(error)
        }
    }

    func resendRecoveryCode(email: String, redirectTo: URL?) async throws {
        do {
            try await client.auth.resetPasswordForEmail(
                email,
                redirectTo: redirectTo ?? authRedirectURL
            )
        } catch {
            throw mapAuthError(error)
        }
    }

    func signOut() async throws {
        do {
            try await client.auth.signOut()
        } catch {
            throw mapAuthError(error)
        }
    }

    func deleteAccount() async throws {
        do {
            let response: DeleteAccountResponse = try await client.functions.invoke(
                "delete-account",
                options: FunctionInvokeOptions(method: .post)
            )

            if response.ok == false {
                throw AuthServiceError.unknown("Failed to delete account.")
            }
        } catch {
            if isLocalProject, shouldFallbackToLocalRPC(for: error) {
                do {
                    try await client
                        .rpc("delete_own_account")
                        .execute()
                    return
                } catch {
                    throw mapAuthError(error)
                }
            }
            throw mapAuthError(error)
        }
    }

    func requestPasswordReset(email: String, redirectTo: URL?) async throws {
        do {
            try await client.auth.resetPasswordForEmail(
                email,
                redirectTo: redirectTo
            )
        } catch {
            throw mapAuthError(error)
        }
    }

    func updatePassword(newPassword: String) async throws -> SessionUser {
        do {
            let user = try await client.auth.update(
                user: UserAttributes(password: newPassword)
            )
            return await sessionUser(from: user)
        } catch {
            throw mapAuthError(error)
        }
    }

    func handleAuthCallback(url: URL) async throws -> SessionUser? {
        do {
            let session = try await client.auth.session(from: url)
            return await sessionUser(from: session.user)
        } catch {
            throw mapAuthError(error)
        }
    }

    func currentUser() async -> SessionUser? {
        if let user = client.auth.currentUser {
            return await sessionUser(from: user)
        }

        do {
            let session = try await client.auth.session
            return await sessionUser(from: session.user)
        } catch {
            do {
                let refreshed = try await client.auth.refreshSession()
                return await sessionUser(from: refreshed.user)
            } catch {
                return nil
            }
        }
    }

    private func sessionUser(from user: User, fallbackUsername: String? = nil) async -> SessionUser {
        let profileUsername = await fetchProfileUsername(for: user.id)
        let metadataUsername = sanitizeUsername(user.userMetadata["username"]?.stringValue)
        let username = profileUsername ?? metadataUsername ?? sanitizeUsername(fallbackUsername)
        return SessionUser(id: user.id, email: user.email, username: username)
    }

    private func sanitizeUsername(_ username: String?) -> String? {
        guard let username else { return nil }
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func persistProfileUsername(_ username: String, for userID: UUID) async throws {
        try await client
            .from("profiles")
            .update(["username": AnyJSON.string(username)])
            .eq("id", value: userID)
            .execute()
    }

    private func fetchProfileUsername(for userID: UUID) async -> String? {
        do {
            let response = try await client
                .from("profiles")
                .select("username")
                .eq("id", value: userID)
                .limit(1)
                .execute()

            let rows = try JSONDecoder().decode([ProfileUsernameRow].self, from: response.data)
            return sanitizeUsername(rows.first?.username)
        } catch {
            return nil
        }
    }

    private func resolveSignInEmail(identifier: String) async -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        if trimmed.contains("@") {
            return trimmed
        }

        do {
            let response = try await client
                .rpc("resolve_sign_in_email", params: ["identifier": trimmed])
                .execute()

            if let resolved = decodeResolvedEmail(from: response.data), !resolved.isEmpty {
                return resolved
            }
        } catch {
            return trimmed
        }

        return trimmed
    }

    private func decodeResolvedEmail(from data: Data) -> String? {
        if let direct = try? JSONDecoder().decode(String.self, from: data) {
            return direct
        }

        if let wrapped = try? JSONDecoder().decode([String: String].self, from: data),
           let value = wrapped.values.first {
            return value
        }

        if let arrayWrapped = try? JSONDecoder().decode([String].self, from: data) {
            return arrayWrapped.first
        }

        return nil
    }

    private var isLocalProject: Bool {
        guard let host = supabaseURL.host?.lowercased() else {
            return false
        }
        return host == "127.0.0.1" || host == "localhost"
    }

    private func shouldFallbackToLocalRPC(for error: Error) -> Bool {
        if let functionsError = error as? FunctionsError {
            switch functionsError {
            case .relayError:
                return true
            case .httpError(let code, _):
                return code == 404 || code == 405 || code == 500 || code == 503
            }
        }

        let message = error.localizedDescription.lowercased()
        return message.contains("delete-account")
            && (message.contains("404") || message.contains("not found") || message.contains("non-2xx"))
    }

    private func mapAuthError(_ error: Error) -> AuthServiceError {
        let message = error.localizedDescription.lowercased()
        if message.contains("already registered")
            || message.contains("email address already in use")
            || message.contains("user already exists")
        {
            return .emailAlreadyInUse
        }
        if message.contains("profiles_username_lower_uidx")
            || (message.contains("username") && message.contains("already"))
            || (message.contains("username") && message.contains("duplicate"))
        {
            return .usernameAlreadyInUse
        }
        if message.contains("password should be at least")
            || message.contains("password is too weak")
            || message.contains("password does not meet the strength requirements")
            || message.contains("weak password")
        {
            return .weakPassword
        }
        if message.contains("email not confirmed")
            || message.contains("email address not authorized")
        {
            return .emailNotConfirmed
        }
        if message.contains("too many requests")
            || message.contains("rate limit")
            || message.contains("over email send rate limit")
            || message.contains("request rate limit reached")
            || message.contains("for security purposes")
        {
            return .rateLimited
        }
        if message.contains("provider is not enabled")
            || message.contains("unsupported provider")
            || message.contains("oauth provider")
        {
            if message.contains("google") {
                return .providerUnavailable("Google")
            }
            if message.contains("apple") {
                return .providerUnavailable("Apple")
            }
            return .providerUnavailable("OAuth")
        }
        if message.contains("invalid otp")
            || message.contains("token not found")
            || message.contains("otp code")
            || message.contains("invalid token")
        {
            return .invalidOTPCode
        }
        if message.contains("invalid login")
            || message.contains("invalid email or password")
            || message.contains("invalid credentials")
        {
            return .invalidCredentials
        }
        if message.contains("otp_expired")
            || message.contains("flow state")
            || message.contains("invalid flow state")
            || message.contains("code verifier")
            || message.contains("auth session missing")
            || message.contains("expired")
            || message.contains("token has expired")
        {
            return .invalidRecoveryLink
        }
        return .unknown(error.localizedDescription)
    }
}

final class SupabaseDeviceTokenSyncService: DeviceTokenSyncing, @unchecked Sendable {
    private enum Keys {
        static let deviceToken = "sunnad.device.push-token"
    }

    private struct DeviceTokenRow: Encodable {
        let userID: UUID
        let platform: String
        let token: String

        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case platform
            case token
        }
    }

    private let client: SupabaseClient
    private let logger: AnalyticsLogging
    private let userDefaults: UserDefaults

    init(
        client: SupabaseClient,
        logger: AnalyticsLogging,
        userDefaults: UserDefaults = .standard
    ) {
        self.client = client
        self.logger = logger
        self.userDefaults = userDefaults
    }

    func syncCurrentDeviceToken(for userID: UUID) async {
        let token = resolveDeviceToken()
        guard let token, !token.isEmpty else {
            logger.log(.syncFinished, metadata: ["scope": "device_token", "status": "skipped_no_token"])
            return
        }

        let row = DeviceTokenRow(userID: userID, platform: "ios", token: token)

        do {
            try await client
                .from("device_tokens")
                .upsert(row, onConflict: "user_id,token")
                .execute()

            logger.log(.syncFinished, metadata: ["scope": "device_token", "status": "upserted"])
        } catch {
            logger.log(
                .storageFailure,
                metadata: [
                    "scope": "device_token_sync",
                    "error": error.localizedDescription
                ]
            )
        }
    }

    private func resolveDeviceToken() -> String? {
        if let override = ProcessInfo.processInfo.environment["SUNNAD_DEBUG_DEVICE_TOKEN"], !override.isEmpty {
            return override
        }

        return userDefaults.string(forKey: Keys.deviceToken)
    }
}
