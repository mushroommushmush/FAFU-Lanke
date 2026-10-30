import Foundation
import XCTest
@testable import CampusCore

private final class SessionProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let query = request.url?.query ?? ""
        if query.contains("offline") {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let page: String
        if query.contains("expired") { page = "<input name='txtUserName'><input name='TextBox2'>" }
        else if query.contains("wrong") { page = "<span id='xhxm'>其他同学</span>" }
        else { page = "<span id='xhxm'>测试同学</span>" }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                       headerFields: ["Content-Type": "text/html; charset=utf-8"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(page.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class SessionTests: XCTestCase {
    private func saved(_ account: String = "valid") -> SavedSession {
        SavedSession(baseURL: URL(string: "http://jwgl.fafu.edu.cn/(abcdefghijklmnopqrstuvwx)/")!,
                     student: Student(account: account, name: "测试"), cookies: [])
    }
    private func client() -> AcademicClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SessionProtocol.self]
        return AcademicClient(configuration: config)
    }
    func testSessionRoundTripRetainsCookielessSessionPathWithoutPassword() throws {
        let original = saved()
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(SavedSession.self, from: data)
        XCTAssertTrue(restored.isValid)
        XCTAssertEqual(restored.baseURL, original.baseURL)
        XCTAssertEqual(restored.student, original.student)
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(fields["password"])
    }
    func testRestoredSessionMustValidateAgainstSchoolBeforeOnline() async throws {
        let client = client()
        try await client.restore(saved())
        let student = try await client.validateSession()
        XCTAssertEqual(student.account, "valid")
    }
    func testExpiredSessionDoesNotBecomeAnOnlineAccount() async throws {
        let client = client()
        try await client.restore(saved("expired"))
        do { _ = try await client.validateSession(); XCTFail("Expected an expired session") }
        catch { XCTAssertEqual(error as? CampusError, .sessionExpired) }
    }
    func testDifferentStudentIsRejected() async throws {
        let client = client()
        try await client.restore(saved("wrong"))
        do { _ = try await client.validateSession(); XCTFail("Expected an identity mismatch") }
        catch { XCTAssertEqual(error as? CampusError, .sessionExpired) }
    }
    func testNetworkFailureDoesNotDestroySessionForRetry() async throws {
        let client = client()
        try await client.restore(saved("offline"))
        do { _ = try await client.validateSession(); XCTFail("Expected a network error") }
        catch { XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet) }
        let retained = await client.savedSession()
        XCTAssertEqual(retained?.student.account, "offline")
    }
    func testSignOutDiscardsRestorableState() async throws {
        let client = client()
        try await client.restore(saved())
        await client.signOut()
        let retained = await client.savedSession()
        XCTAssertNil(retained)
    }
    func testRestorationRejectsExternalHost() async {
        let client = client()
        let external = SavedSession(baseURL: URL(string: "https://example.com/")!,
                                    student: Student(account: "sample", name: "测试"), cookies: [])
        do { try await client.restore(external); XCTFail("Expected rejected destination") }
        catch { XCTAssertEqual(error as? CampusError, .invalidDestination) }
    }
    func testCookieScopeAndExpiryAreEnforced() throws {
        let foreign = try XCTUnwrap(HTTPCookie(properties: [.name: "session", .value: "example",
            .domain: "example.com", .path: "/"]))
        XCTAssertNil(SessionCookie(foreign).httpCookie)
        let expired = try XCTUnwrap(HTTPCookie(properties: [.name: "session", .value: "example",
            .domain: AcademicClient.host, .path: "/", .expires: Date(timeIntervalSince1970: 1)]))
        XCTAssertNil(SessionCookie(expired).httpCookie)
        let valid = try XCTUnwrap(HTTPCookie(properties: [.name: "session", .value: "example",
            .domain: AcademicClient.host, .path: "/"]))
        XCTAssertEqual(SessionCookie(valid).httpCookie?.value, "example")
    }
}
