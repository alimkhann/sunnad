import CryptoKit
import Foundation

actor AvatarImageCache {
    static let shared = AvatarImageCache()

    private let fileManager: FileManager
    private let cacheDirectoryURL: URL
    private var memoryCache: [String: Data] = [:]

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        self.cacheDirectoryURL = base.appendingPathComponent("sunnad-avatar-cache", isDirectory: true)
        if !fileManager.fileExists(atPath: cacheDirectoryURL.path) {
            try? fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        }
    }

    func data(for url: URL) async -> Data? {
        let key = cacheKey(for: url)

        if let cached = memoryCache[key] {
            return cached
        }

        if let disk = loadFromDisk(key: key) {
            memoryCache[key] = disk
            return disk
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard data.isEmpty == false else {
                return nil
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return nil
            }
            store(data: data, forKey: key)
            return data
        } catch {
            return nil
        }
    }

    func preload(url: URL?) async {
        guard let url else { return }
        _ = await data(for: url)
    }

    func invalidate(url: URL?) async {
        guard let url else { return }
        let key = cacheKey(for: url)
        memoryCache.removeValue(forKey: key)
        try? fileManager.removeItem(at: diskURL(for: key))
    }

    private func store(data: Data, forKey key: String) {
        memoryCache[key] = data
        let destination = diskURL(for: key)
        do {
            try data.write(to: destination, options: [.atomic])
        } catch {
            // Ignore cache write failures; they should never block UI flows.
        }
    }

    private func loadFromDisk(key: String) -> Data? {
        let path = diskURL(for: key)
        return try? Data(contentsOf: path)
    }

    private func diskURL(for key: String) -> URL {
        cacheDirectoryURL.appendingPathComponent(key).appendingPathExtension("bin")
    }

    private func cacheKey(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
