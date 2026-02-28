import Foundation

final class AnalyticsErrorBridgeLogger: AnalyticsLogging, @unchecked Sendable {
    private let baseLogger: AnalyticsLogging
    private let dedupeWindow: TimeInterval
    private let lock = NSLock()
    private var analyticsClient: AnalyticsClient?
    private var recentErrorTimestamps: [String: Date] = [:]

    init(
        baseLogger: AnalyticsLogging,
        analyticsClient: AnalyticsClient? = nil,
        dedupeWindow: TimeInterval = 45
    ) {
        self.baseLogger = baseLogger
        self.analyticsClient = analyticsClient
        self.dedupeWindow = dedupeWindow
    }

    func setAnalyticsClient(_ client: AnalyticsClient) {
        lock.withLock {
            analyticsClient = client
        }
    }

    func log(_ event: AnalyticsEvent, metadata: [String: String]) {
        baseLogger.log(event, metadata: metadata)
        guard event == .storageFailure else { return }
        guard let properties = sanitizedErrorProperties(metadata: metadata) else { return }

        let client = lock.withLock { analyticsClient }
        client?.capture("ios_error_captured", properties: properties)
    }

    private func sanitizedErrorProperties(metadata: [String: String]) -> [String: Any]? {
        let now = Date()
        let scope = metadata["scope"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "unknown"
        let error = metadata["error"] ?? ""
        let messageHash = fnv1aHash(error.lowercased())
        let dedupeKey = "\(scope)|\(messageHash)"

        let shouldCapture = lock.withLock { () -> Bool in
            if let last = recentErrorTimestamps[dedupeKey], now.timeIntervalSince(last) < dedupeWindow {
                return false
            }
            recentErrorTimestamps[dedupeKey] = now
            recentErrorTimestamps = recentErrorTimestamps.filter { now.timeIntervalSince($0.value) < dedupeWindow * 2 }
            return true
        }

        guard shouldCapture else { return nil }

        var properties: [String: Any] = [
            "scope": scope,
            "error_kind": errorKind(scope: scope, error: error),
            "message_hash": messageHash,
        ]

        if let code = extractErrorCode(from: error) {
            properties["error_code"] = code
        }
        return properties
    }

    private func errorKind(scope: String, error: String) -> String {
        let value = "\(scope) \(error)".lowercased()
        if value.contains("sync") {
            return "sync_failure"
        }
        if value.contains("network") || value.contains("url") || value.contains("socket") || value.contains("http") {
            return "network_failure"
        }
        if value.contains("storage") || value.contains("db") || value.contains("model") {
            return "storage_failure"
        }
        return "unknown"
    }

    private func extractErrorCode(from error: String) -> String? {
        guard !error.isEmpty else { return nil }
        let pattern = #"(?i)\b(?:code|status)\s*[:=]?\s*([a-z0-9_\-#\.]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsError = error as NSString
        let range = NSRange(location: 0, length: nsError.length)
        guard let match = regex.firstMatch(in: error, options: [], range: range), match.numberOfRanges > 1 else {
            return nil
        }
        let captured = nsError.substring(with: match.range(at: 1))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return captured.isEmpty ? nil : captured
    }

    private func fnv1aHash(_ value: String) -> String {
        let prime: UInt64 = 1_099_511_628_211
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return String(hash, radix: 16)
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
