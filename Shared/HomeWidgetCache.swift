import Foundation
import Security
import CampusCore

enum HomeWidgetCache {
    static let service = "app.personal.fafucampus.widget-courses"
    private static var cachedGroup: String?
    static func group() throws -> String {
        if let cachedGroup { return cachedGroup }
        let probe: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "app.personal.fafucampus.widget-probe", kSecAttrAccount as String: "prefix",
            kSecReturnAttributes as String: true]
        var result: CFTypeRef?
        var status = SecItemCopyMatching(probe as CFDictionary, &result)
        if status == errSecItemNotFound {
            var add = probe
            add[kSecValueData as String] = Data([0])
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(add as CFDictionary, &result)
        }
        guard status == errSecSuccess, let attributes = result as? [String: Any],
              let ownGroup = attributes[kSecAttrAccessGroup as String] as? String,
              let prefix = ownGroup.split(separator: ".").first else { throw CacheError.status(status) }
        let value = String(prefix) + ".app.personal.fafucampus.widget-data"
        cachedGroup = value
        return value
    }
    static func read() throws -> HomeWidgetSnapshot? {
        var query = try base()
        query[kSecReturnData as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw CacheError.status(status) }
        return try JSONDecoder().decode(HomeWidgetSnapshot.self, from: data)
    }
    static func write(_ value: HomeWidgetSnapshot) throws {
        let data = try JSONEncoder().encode(value)
        let query = try base()
        let change: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, change as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let result = SecItemAdd(add as CFDictionary, nil)
            guard result == errSecSuccess else { throw CacheError.status(result) }
        } else if status != errSecSuccess { throw CacheError.status(status) }
    }
    static func clear() throws {
        let status = SecItemDelete(try base() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw CacheError.status(status) }
    }
    private static func base() throws -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: "active-courses", kSecAttrAccessGroup as String: try group()]
    }
    enum CacheError: LocalizedError {
        case status(OSStatus)
        var errorDescription: String? { if case .status(let code) = self { return "小组件共享权限不可用（\(code)）。重新签名可能未保留共享钥匙串权限。" }; return nil }
    }
}
