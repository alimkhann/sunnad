import Foundation
import Supabase

final class SupabaseAuthService: AuthService, @unchecked Sendable {
    private struct ProfileUsernameRow: Decodable {
        let username: String?
    }

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func signUp(email: String, password: String, username: String?) async throws -> SessionUser {
        do {
            let cleanedUsername = sanitizeUsername(username)
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: cleanedUsername.flatMap { value in
                    ["username": AnyJSON.string(value)]
                }
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
            return await sessionUser(from: response.user, fallbackUsername: cleanedUsername)
        } catch {
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

    func signOut() async throws {
        do {
            try await client.auth.signOut()
        } catch {
            throw mapAuthError(error)
        }
    }

    func deleteAccount() async throws {
        do {
            try await client
                .rpc("delete_own_account")
                .execute()
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
            return nil
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
        if message.contains("invalid login")
            || message.contains("invalid email or password")
            || message.contains("invalid credentials")
        {
            return .invalidCredentials
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
