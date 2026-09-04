import Foundation
import Supabase

final class SupabaseAuthService: AuthService, @unchecked Sendable {
    private struct ProfileRow: Decodable, Sendable {
        let username: String?
        let avatarPath: String?
        let updatedAtRaw: String?

        var updatedAt: Date? {
            SupabaseAuthService.parseProfileTimestamp(updatedAtRaw)
        }

        enum CodingKeys: String, CodingKey {
            case username
            case avatarPath = "avatar_path"
            case updatedAtRaw = "updated_at"
        }
    }

    private enum ProfileLookup: Sendable {
        case found(ProfileRow)
        case missing
        case unavailable
    }

    private struct DeleteAccountResponse: Decodable {
        let ok: Bool?
    }

    private struct ProfileUsernameUpsertRow: Encodable {
        let id: UUID
        let username: String
    }

    private struct ProfileAvatarUpsertRow: Encodable {
        let id: UUID
        let avatarPath: String?

        enum CodingKeys: String, CodingKey {
            case id
            case avatarPath = "avatar_path"
        }
    }

    private let client: SupabaseClient
    private let supabaseURL: URL
    private let authRedirectURL: URL?
    private let usernameRegex = try? NSRegularExpression(pattern: "^[a-z0-9_]{3,20}$")

    init(client: SupabaseClient, supabaseURL: URL, authRedirectURL: URL?) {
        self.client = client
        self.supabaseURL = supabaseURL
        self.authRedirectURL = authRedirectURL
    }

    func signUp(email: String, password: String, username: String?) async throws -> SessionUser {
        do {
            let hasUsernameInput = !(username?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            let cleanedUsername = sanitizeUsername(username)
            if hasUsernameInput, cleanedUsername == nil {
                throw AuthServiceError.invalidUsername
            }
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
        do {
            let token = try await AppleSignInCoordinator().start()
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: token.idToken,
                    nonce: token.nonce
                )
            )
            return await sessionUser(from: session.user)
        } catch let error as AppleSignInError {
            switch error {
            case .cancelled:
                throw AuthServiceError.unknown("Sign in was cancelled.")
            case .missingPresentationAnchor:
                throw AuthServiceError.unknown("Unable to present Apple sign in. Please try again.")
            case .invalidResponse, .missingIdentityToken:
                throw AuthServiceError.unknown("Apple sign in did not return a valid identity token.")
            case .nonceGenerationFailed:
                throw AuthServiceError.unknown("Unable to securely start Apple sign in. Please try again.")
            }
        } catch {
            throw mapAuthError(error)
        }
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

    func fetchProfile() async throws -> SessionUser {
        guard let user = await currentAuthUser() else {
            throw AuthServiceError.invalidCredentials
        }
        return await sessionUser(from: user)
    }

    func updateUsername(_ username: String) async throws -> SessionUser {
        guard let user = await currentAuthUser() else {
            throw AuthServiceError.invalidCredentials
        }

        guard let cleanedUsername = sanitizeUsername(username) else {
            throw AuthServiceError.invalidUsername
        }

        do {
            try await persistProfileUsername(cleanedUsername, for: user.id)
            _ = try? await client.auth.update(
                user: UserAttributes(data: ["username": AnyJSON.string(cleanedUsername)])
            )
            return try await fetchProfile()
        } catch {
            throw mapAuthError(error)
        }
    }

    func uploadAvatar(data: Data, mimeType: String) async throws -> SessionUser {
        guard let user = await currentAuthUser() else {
            throw AuthServiceError.invalidCredentials
        }

        let fileExtension = fileExtension(for: mimeType)
        let avatarPath = "profiles/\(user.id.uuidString.lowercased())/avatar.\(fileExtension)"

        do {
            _ = try await client.storage.from("avatars").upload(
                avatarPath,
                data: data,
                options: FileOptions(
                    cacheControl: "31536000",
                    contentType: mimeType,
                    upsert: true
                )
            )
            try await persistProfileAvatarPath(avatarPath, for: user.id)
            return try await fetchProfile()
        } catch {
            throw mapAuthError(error)
        }
    }

    func removeAvatar() async throws -> SessionUser {
        guard let user = await currentAuthUser() else {
            throw AuthServiceError.invalidCredentials
        }

        let profile = await fetchProfileRow(for: user.id)
        let avatarPath = profile?.avatarPath?.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if let avatarPath, !avatarPath.isEmpty, !avatarPath.lowercased().hasPrefix("http") {
                _ = try await client.storage.from("avatars").remove(paths: [avatarPath])
            }

            try await persistProfileAvatarPath(nil, for: user.id)
            return try await fetchProfile()
        } catch {
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

    private func sessionUser(
        from user: User,
        fallbackUsername: String? = nil,
        fetchRemoteProfile: Bool = true
    ) async -> SessionUser {
        let provider = authProvider(from: user)
        let profileLookup = fetchRemoteProfile
            ? await fetchProfileLookupBounded(for: user.id)
            : ProfileLookup.unavailable
        let profile: ProfileRow?
        switch profileLookup {
        case .found(let resolvedProfile):
            profile = resolvedProfile
        case .missing, .unavailable:
            profile = nil
        }
        var username = sanitizeUsername(profile?.username)
        let metadataUsername = sanitizeUsername(user.userMetadata["username"]?.stringValue)

        if username == nil, let metadataUsername {
            username = metadataUsername
            if case .missing = profileLookup {
                try? await persistProfileUsername(metadataUsername, for: user.id)
            }
        }

        if username == nil, let fallbackUsername = sanitizeUsername(fallbackUsername) {
            username = fallbackUsername
            try? await persistProfileUsername(fallbackUsername, for: user.id)
        }

        if username == nil,
           case .missing = profileLookup,
           provider == .google || provider == .apple {
            let base = oauthUsernameBase(from: user) ?? "user"
            if let claimed = await claimOAuthUsername(base: base) {
                username = claimed
            }
        }

        var avatarPath = profile?.avatarPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let providerAvatarURL = oauthAvatarURL(from: user)
        if (avatarPath == nil || avatarPath?.isEmpty == true), let providerAvatarURL {
            try? await persistProfileAvatarPath(providerAvatarURL.absoluteString, for: user.id)
            avatarPath = providerAvatarURL.absoluteString
        }

        let avatarURL = avatarURL(from: avatarPath, updatedAt: profile?.updatedAt)
        return SessionUser(
            id: user.id,
            email: user.email,
            username: username,
            avatarURL: avatarURL,
            provider: provider
        )
    }

    private func sanitizeUsername(_ username: String?) -> String? {
        guard let username else { return nil }
        let normalized = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { return nil }

        let range = NSRange(location: 0, length: normalized.utf16.count)
        guard usernameRegex?.firstMatch(in: normalized, options: [], range: range) != nil else {
            return nil
        }
        return normalized
    }

    private func persistProfileUsername(_ username: String, for userID: UUID) async throws {
        do {
            try await client
                .rpc(
                    "upsert_profile_fields",
                    params: [
                        "p_username": AnyJSON.string(username),
                        "p_set_username": AnyJSON.bool(true)
                    ]
                )
                .execute()
        } catch {
            let row = ProfileUsernameUpsertRow(id: userID, username: username)
            try await client
                .from("profiles")
                .upsert(row, onConflict: "id")
                .execute()
        }
    }

    private func persistProfileAvatarPath(_ avatarPath: String?, for userID: UUID) async throws {
        do {
            try await client
                .rpc(
                    "upsert_profile_fields",
                    params: [
                        "p_avatar_path": avatarPath.map(AnyJSON.string) ?? AnyJSON.null,
                        "p_set_avatar": AnyJSON.bool(true)
                    ]
                )
                .execute()
        } catch {
            let row = ProfileAvatarUpsertRow(id: userID, avatarPath: avatarPath)
            try await client
                .from("profiles")
                .upsert(row, onConflict: "id")
                .execute()
        }
    }

    private func fetchProfileRow(for userID: UUID) async -> ProfileRow? {
        if case .found(let profile) = await fetchProfileLookup(for: userID) {
            return profile
        }
        return nil
    }

    private func fetchProfileLookup(for userID: UUID) async -> ProfileLookup {
        do {
            let response = try await client
                .from("profiles")
                .select("username, avatar_path, updated_at")
                .eq("id", value: userID)
                .limit(1)
                .execute()

            let rows = try JSONDecoder().decode([ProfileRow].self, from: response.data)
            if let profile = rows.first {
                return .found(profile)
            }
            return .missing
        } catch {
            return .unavailable
        }
    }

    private func fetchProfileLookupBounded(
        for userID: UUID,
        timeoutNanoseconds: UInt64 = 1_500_000_000
    ) async -> ProfileLookup {
        await withTaskGroup(of: ProfileLookup.self) { group in
            group.addTask { await self.fetchProfileLookup(for: userID) }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return .unavailable
            }
            let first = await group.next() ?? .unavailable
            group.cancelAll()
            return first
        }
    }

    private func claimOAuthUsername(base: String) async -> String? {
        do {
            let response = try await client
                .rpc("claim_oauth_username", params: ["base": base])
                .execute()
            return decodeResolvedEmail(from: response.data).flatMap(sanitizeUsername)
        } catch {
            return nil
        }
    }

    private func oauthUsernameBase(from user: User) -> String? {
        if let candidate = sanitizeUsername(user.userMetadata["preferred_username"]?.stringValue) {
            return candidate
        }
        if let candidate = sanitizeUsername(user.userMetadata["user_name"]?.stringValue) {
            return candidate
        }
        if let candidate = sanitizeUsername(user.userMetadata["name"]?.stringValue) {
            return candidate
        }
        if let candidate = sanitizeUsername(user.userMetadata["full_name"]?.stringValue) {
            return candidate
        }

        if let email = user.email?.lowercased(), let at = email.firstIndex(of: "@") {
            return sanitizeUsername(String(email[..<at]))
        }

        return nil
    }

    private func oauthAvatarURL(from user: User) -> URL? {
        if let avatar = user.userMetadata["avatar_url"]?.stringValue, let url = URL(string: avatar) {
            return url
        }
        if let picture = user.userMetadata["picture"]?.stringValue, let url = URL(string: picture) {
            return url
        }
        return nil
    }

    private func avatarURL(from avatarPath: String?, updatedAt: Date?) -> URL? {
        guard let avatarPath, !avatarPath.isEmpty else {
            return nil
        }

        if avatarPath.lowercased().hasPrefix("http://") || avatarPath.lowercased().hasPrefix("https://") {
            return URL(string: avatarPath)
        }

        guard var publicURL = try? client.storage.from("avatars").getPublicURL(path: avatarPath, download: false) else {
            return nil
        }

        if let updatedAt {
            var components = URLComponents(url: publicURL, resolvingAgainstBaseURL: false)
            var queryItems = components?.queryItems ?? []
            queryItems.append(URLQueryItem(name: "v", value: String(Int(updatedAt.timeIntervalSince1970))))
            components?.queryItems = queryItems
            if let cacheBusted = components?.url {
                publicURL = cacheBusted
            }
        }

        return publicURL
    }

    private static func parseProfileTimestamp(_ rawValue: String?) -> Date? {
        guard let rawValue, !rawValue.isEmpty else { return nil }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = fractional.date(from: rawValue) {
            return parsed
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: rawValue)
    }

    private func currentAuthUser() async -> User? {
        if let user = client.auth.currentUser {
            return user
        }
        if let session = try? await client.auth.session {
            return session.user
        }
        return nil
    }

    private func authProvider(from user: User) -> AuthProvider {
        let rawProvider = user.appMetadata["provider"]?.stringValue?.lowercased() ?? ""
        switch rawProvider {
        case "email":
            return .email
        case "google":
            return .google
        case "apple":
            return .apple
        default:
            return .unknown
        }
    }

    private func fileExtension(for mimeType: String) -> String {
        switch mimeType.lowercased() {
        case "image/png":
            return "png"
        case "image/webp":
            return "webp"
        default:
            return "jpg"
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
        if message.contains("profiles_username_format_check")
            || (message.contains("username") && message.contains("must"))
            || (message.contains("username") && message.contains("invalid"))
        {
            return .invalidUsername
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
        if message.contains("row-level security policy")
            || message.contains("violates row-level security")
        {
            return .unknown("Permission denied. Please sign in again and retry.")
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
        let installationID: UUID
        let apnsEnvironment: String

        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case platform
            case token
            case installationID = "installation_id"
            case apnsEnvironment = "apns_environment"
        }
    }

    private struct ProfileContextRow: Encodable {
        let id: UUID
        let locale: String
        let timeZone: String

        enum CodingKeys: String, CodingKey {
            case id
            case locale
            case timeZone = "time_zone"
        }
    }

    private let client: SupabaseClient
    private let logger: AnalyticsLogging
    private let userDefaults: UserDefaults
    private let installationIdentifierStore: InstallationIdentifierStore
    private let apnsEnvironment: String

    init(
        client: SupabaseClient,
        logger: AnalyticsLogging,
        apnsEnvironment: String = "production",
        userDefaults: UserDefaults = .standard,
        installationIdentifierStore: InstallationIdentifierStore = InstallationIdentifierStore()
    ) {
        self.client = client
        self.logger = logger
        self.userDefaults = userDefaults
        self.installationIdentifierStore = installationIdentifierStore
        self.apnsEnvironment = apnsEnvironment == "development" ? "development" : "production"
    }

    func syncCurrentDeviceToken(for userID: UUID) async {
        let resolvedToken = resolveDeviceToken()
        guard let resolvedToken, !resolvedToken.isEmpty else {
            logger.log(.syncFinished, metadata: ["scope": "device_token", "status": "skipped_no_token"])
            return
        }

        let row = DeviceTokenRow(
            userID: userID,
            platform: "ios",
            token: resolvedToken,
            installationID: installationIdentifierStore.identifier(),
            apnsEnvironment: apnsEnvironment
        )

        do {
            try await client
                .from("device_tokens")
                .delete()
                .eq("user_id", value: userID)
                .eq("installation_id", value: installationIdentifierStore.identifier())
                .execute()
            try await client
                .from("device_tokens")
                .delete()
                .eq("user_id", value: userID)
                .eq("token", value: resolvedToken)
                .execute()
            try await client
                .from("device_tokens")
                .insert(row)
                .execute()

            logger.log(
                .syncFinished,
                metadata: [
                    "scope": "device_token",
                    "status": "upserted",
                    "environment": apnsEnvironment
                ]
            )
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

    func setGroupRemindersEnabled(_ enabled: Bool, for userID: UUID) async {
        do {
            try await client
                .from("profiles")
                .update(["group_nudges_enabled": enabled])
                .eq("id", value: userID)
                .execute()
            if enabled {
                await syncCurrentDeviceToken(for: userID)
            }
            logger.log(
                .syncFinished,
                metadata: ["scope": "device_token_group_receive", "status": enabled ? "enabled" : "disabled"]
            )
        } catch {
            logger.log(
                .storageFailure,
                metadata: ["scope": "device_token_group_receive", "error": error.localizedDescription]
            )
        }
    }

    func syncProfileContext(for userID: UUID, locale: String, timeZone: String) async {
        let supportedLocale = ["en", "ru", "kk"].contains(locale) ? locale : "en"
        let resolvedTimeZone = TimeZone(identifier: timeZone)?.identifier ?? "UTC"
        do {
            try await client
                .from("profiles")
                .upsert(
                    ProfileContextRow(
                        id: userID,
                        locale: supportedLocale,
                        timeZone: resolvedTimeZone
                    ),
                    onConflict: "id"
                )
                .execute()
        } catch {
            logger.log(
                .storageFailure,
                metadata: ["scope": "profile_context_sync", "error": error.localizedDescription]
            )
        }
    }

    func removeCurrentInstallation(for userID: UUID) async {
        do {
            try await client
                .from("device_tokens")
                .delete()
                .eq("user_id", value: userID)
                .eq("installation_id", value: installationIdentifierStore.identifier())
                .execute()
        } catch {
            logger.log(
                .storageFailure,
                metadata: ["scope": "device_token_remove", "error": error.localizedDescription]
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
