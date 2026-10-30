import Foundation

public struct SessionCookie: Codable, Sendable {
    public let name: String
    public let value: String
    public let domain: String
    public let path: String
    public let expires: Date?
    public let secure: Bool
    public init(_ cookie: HTTPCookie) {
        name = cookie.name; value = cookie.value; domain = cookie.domain
        path = cookie.path; expires = cookie.expiresDate; secure = cookie.isSecure
    }
    public var httpCookie: HTTPCookie? {
        guard domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased() == AcademicClient.host,
              expires.map({ $0 > Date() }) ?? true else { return nil }
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: name, .value: value, .domain: domain, .path: path
        ]
        if secure { properties[.secure] = "TRUE" }
        if let expires { properties[.expires] = expires }
        return HTTPCookie(properties: properties)
    }
}

/// Authentication material. Persist only in Keychain, never in the records cache.
public struct SavedSession: Codable, Sendable {
    public let schemaVersion: Int
    public let baseURL: URL
    public let student: Student
    public let cookies: [SessionCookie]
    public init(baseURL: URL, student: Student, cookies: [SessionCookie]) {
        schemaVersion = 1; self.baseURL = baseURL; self.student = student; self.cookies = cookies
    }
    public var isValid: Bool {
        schemaVersion == 1 && AcademicClient.isAllowed(baseURL)
            && baseURL.query == nil && baseURL.fragment == nil
            && baseURL.absoluteString.hasSuffix("/") && !student.account.isEmpty && !student.name.isEmpty
    }
}
