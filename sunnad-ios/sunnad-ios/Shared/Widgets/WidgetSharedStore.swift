import Foundation

// Security note: widget session material (access token) lives in the shared App
// Group container, which is readable only by this app's own targets (app +
// widget extension), not by other apps. Upgrade path: move the access token
// into a shared keychain access group (keychain-access-groups entitlement) and
// keep only non-secret routing hints in the App Group UserDefaults.
struct WidgetSession: Codable, Equatable, Sendable {
    var supabaseURL: String
    var anonKey: String
    var accessToken: String
    var userID: UUID
}

struct WidgetSharedStore {
    private enum Keys {
        static let snapshotFile = "widget-snapshot.json"
        static let pendingFile = "widget-pending.json"
        static let snapshotData = "widget.snapshot.data"
        static let pendingData = "widget.pending.data"
        static let sessionSupabaseURL = "widget.session.supabaseURL"
        static let sessionAnonKey = "widget.session.anonKey"
        static let sessionAccessToken = "widget.session.accessToken"
        static let sessionUserID = "widget.session.userID"
    }

    private let userDefaults: UserDefaults
    private let containerURL: URL?
    private let lock = NSLock()

    /// File-backed storage is preferred (App Group container); when the
    /// container URL is unavailable (unprovisioned simulator), snapshot and
    /// pending payloads fall back to the group UserDefaults as JSON blobs.
    static func makeShared() -> WidgetSharedStore? {
        guard let groupID = Bundle.main.object(forInfoDictionaryKey: "SunnadAppGroupID") as? String,
              !groupID.isEmpty,
              let defaults = UserDefaults(suiteName: groupID) else {
            return nil
        }
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
        return WidgetSharedStore(userDefaults: defaults, containerURL: container)
    }

    init(userDefaults: UserDefaults, containerURL: URL?) {
        self.userDefaults = userDefaults
        self.containerURL = containerURL
    }

    // MARK: - Snapshot

    func readSnapshot() -> TodaySnapshot? {
        var data: Data?
        if let containerURL {
            data = try? Data(contentsOf: url(for: Keys.snapshotFile))
        }
        if data == nil {
            data = userDefaults.data(forKey: Keys.snapshotData)
        }
        guard let data else {
            return nil
        }
        return try? JSONDecoder().decode(TodaySnapshot.self, from: data)
    }

    @discardableResult
    func writeSnapshot(_ snapshot: TodaySnapshot) -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else {
            return false
        }
        if let containerURL {
            return atomicWrite(data, to: url(for: Keys.snapshotFile))
        }
        userDefaults.set(data, forKey: Keys.snapshotData)
        return true
    }

    // MARK: - Pending changes

    func readPending() -> [PendingChange] {
        var data: Data?
        if let containerURL {
            data = try? Data(contentsOf: url(for: Keys.pendingFile))
        }
        if data == nil {
            data = userDefaults.data(forKey: Keys.pendingData)
        }
        guard let data else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([PendingChange].self, from: data)) ?? []
    }

    @discardableResult
    func replacePending(_ changes: [PendingChange]) -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(changes) else {
            return false
        }
        lock.lock()
        defer { lock.unlock() }
        if let containerURL {
            return atomicWrite(data, to: url(for: Keys.pendingFile))
        }
        userDefaults.set(data, forKey: Keys.pendingData)
        return true
    }

    @discardableResult
    func appendPending(_ change: PendingChange) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let pending = readPending()
        let updated = PendingChangeQueue.appending(change, to: pending)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(updated) else {
            return false
        }
        if let containerURL {
            return atomicWrite(data, to: url(for: Keys.pendingFile))
        }
        userDefaults.set(data, forKey: Keys.pendingData)
        return true
    }

    // MARK: - Session

    func saveSession(_ session: WidgetSession) {
        userDefaults.set(session.supabaseURL, forKey: Keys.sessionSupabaseURL)
        userDefaults.set(session.anonKey, forKey: Keys.sessionAnonKey)
        userDefaults.set(session.accessToken, forKey: Keys.sessionAccessToken)
        userDefaults.set(session.userID.uuidString, forKey: Keys.sessionUserID)
    }

    func clearSession() {
        userDefaults.removeObject(forKey: Keys.sessionSupabaseURL)
        userDefaults.removeObject(forKey: Keys.sessionAnonKey)
        userDefaults.removeObject(forKey: Keys.sessionAccessToken)
        userDefaults.removeObject(forKey: Keys.sessionUserID)
    }

    func readSession() -> WidgetSession? {
        guard let supabaseURL = userDefaults.string(forKey: Keys.sessionSupabaseURL),
              let anonKey = userDefaults.string(forKey: Keys.sessionAnonKey),
              let accessToken = userDefaults.string(forKey: Keys.sessionAccessToken),
              let userIDRaw = userDefaults.string(forKey: Keys.sessionUserID),
              let userID = UUID(uuidString: userIDRaw),
              !accessToken.isEmpty else {
            return nil
        }
        return WidgetSession(
            supabaseURL: supabaseURL,
            anonKey: anonKey,
            accessToken: accessToken,
            userID: userID
        )
    }

    // MARK: - Helpers

    private func url(for file: String) -> URL {
        (containerURL ?? FileManager.default.temporaryDirectory).appendingPathComponent(file)
    }

    /// Two processes (app + extension) write this container; writes go through
    /// a temp file + rename so readers never observe a torn file.
    private func atomicWrite(_ data: Data, to destination: URL) -> Bool {
        let temporaryURL = destination.deletingLastPathComponent()
            .appendingPathComponent(UUID().uuidString + ".tmp")
        do {
            try data.write(to: temporaryURL, options: .atomic)
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporaryURL)
            return true
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            if (try? data.write(to: destination, options: .atomic)) != nil {
                return true
            }
            return false
        }
    }
}
