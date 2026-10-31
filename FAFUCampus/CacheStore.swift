import Foundation
import Security
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

/// One device-local Keychain item; never synchronized to iCloud.
struct SessionVault {
    private var key: [String: Any] { [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "app.personal.fafucampus.session",
        kSecAttrAccount as String: "current-session"
    ] }
    func load() throws -> SavedSession? {
        var query = key
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw failure(status) }
        let saved = try JSONDecoder().decode(SavedSession.self, from: data)
        guard saved.isValid else { throw CampusError.invalidDestination }
        return saved
    }
    func save(_ saved: SavedSession) throws {
        guard saved.isValid else { throw CampusError.invalidDestination }
        let data = try JSONEncoder().encode(saved)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(key as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = key
            for (name, value) in attributes { item[name] = value }
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw failure(added) }
        } else if status != errSecSuccess { throw failure(status) }
    }
    func clear() throws {
        let status = SecItemDelete(key as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw failure(status) }
    }
    private func failure(_ status: OSStatus) -> CampusError {
        .message("无法读写本机登录状态（钥匙串错误码：\(status)）。")
    }
}

struct LoginCredentials: Codable { let account: String; let password: String }
struct CredentialsVault {
    private var key: [String: Any] { [kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "app.personal.fafucampus.credentials", kSecAttrAccount as String: "remembered"] }
    func load() -> LoginCredentials? {
        var query = key; query[kSecReturnData as String] = true
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(LoginCredentials.self, from: data)
    }
    func clear() { SecItemDelete(key as CFDictionary) }
    func save(_ value: LoginCredentials) throws {
        let data = try JSONEncoder().encode(value)
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status = SecItemUpdate(key as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = key; attributes.forEach { item[$0.key] = $0.value }
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw CampusError.message("无法保存自动登录信息（\(status)）。") }
    }
}
