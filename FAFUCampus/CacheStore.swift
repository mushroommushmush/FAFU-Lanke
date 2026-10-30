import Foundation
import CampusCore

/// Stores academic records only. Passwords, cookies and HTML are never serialized.
struct CacheStore {
    private var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FAFUCampus", isDirectory: true).appendingPathComponent("snapshot.json")
    }
    func load() -> CampusSnapshot? {
        guard let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(CampusSnapshot.self, from: data),
              snapshot.schemaVersion == 1 else { return nil }
        return snapshot
    }
    func save(_ snapshot: CampusSnapshot) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete])
        var excluded = directory
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try excluded.setResourceValues(values)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }
    func clear() throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
