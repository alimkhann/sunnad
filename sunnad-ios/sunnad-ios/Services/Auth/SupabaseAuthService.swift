import Foundation
import Supabase

final class SupabaseAuthService: AuthService, @unchecked Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func signUp(email: String, password: String, username: String?) async throws -> SessionUser {
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: username.flatMap { value in
                    guard !value.isEmpty else { return nil }
                    return ["username": AnyJSON.string(value)]
                }
            )

            if let session = response.session {
                return mapUser(session.user)
            }

            return mapUser(response.user)
        } catch {
            throw mapAuthError(error)
        }
    }

    func signIn(email: String, password: String) async throws -> SessionUser {
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            return mapUser(session.user)
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

    func currentUser() async -> SessionUser? {
        if let user = client.auth.currentUser {
            return mapUser(user)
        }

        do {
            let session = try await client.auth.session
            return mapUser(session.user)
        } catch {
            return nil
        }
    }

    private func mapUser(_ user: User) -> SessionUser {
        SessionUser(id: user.id, email: user.email, username: nil)
    }

    private func mapAuthError(_ error: Error) -> AuthServiceError {
        let message = error.localizedDescription.lowercased()
        if message.contains("invalid login") || message.contains("invalid") {
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
