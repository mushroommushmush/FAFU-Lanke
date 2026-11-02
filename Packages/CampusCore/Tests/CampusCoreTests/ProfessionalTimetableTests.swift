import Foundation
import XCTest
@testable import CampusCore

private func professionalHTML(_ state: String = "state+1=", action: String = "tjkbcx.aspx?xh=test") -> String {
    let options = [("xn", "2026-2027", "2026-2027"), ("xq", "1", "1"), ("nj", "2024", "2024"), ("xy", "630", "经济与管理学院"), ("zy", "6304", "金融学"), ("kb", "opaque-class", "24金融1班")]
    let selectors = options.map { "<select name='\($0.0)'><option value=''>请选择</option><option selected value='\($0.1)'>\($0.2)</option></select>" }.joined()
    return """
    <form action="\(action)"><input type="hidden" name="__VIEWSTATE" value="\(state)"><input type="hidden" name="__EVENTVALIDATION" value="token+two">
    \(selectors)<table id="Table1"><tr><td>筛选区域</td></tr></table>
    <table id="Table6"><tr><th>时间</th><th>星期一</th><th>星期二</th><th>星期三</th><th>星期四</th><th>星期五</th><th>星期六</th><th>星期日</th></tr>
    <tr><td>第1节</td><td rowspan="2">微观经济学<br>7-9,15-16(1,2)/田604/卢老师<br>金融学<br>6-18双(1,2)/诚A601/陈老师</td><td></td><td></td><td></td><td></td><td></td><td></td></tr>
    <tr><td>第2节</td><td></td><td></td><td></td><td></td><td></td><td></td></tr></table>
    <table id="DataGrid1"><tr><td>实践课程</td><td>专业实习，无固定时间</td></tr></table>
    <table id="DBGrid"><tr><td>调课说明</td><td>以学校记录为准</td></tr></table></form>
    """
}

private final class ProfessionalProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let page = professionalHTML(request.httpMethod == "POST" ? "new-state" : "old+state=")
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/html; charset=utf-8"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(page.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class ProfessionalTimetableTests: XCTestCase {
    func testDynamicSelectorsHiddenFieldsAndDedicatedTable() throws {
        let page = try HTMLParser.professional(professionalHTML())
        XCTAssertEqual(page.selected["kb"], "opaque-class")
        XCTAssertEqual(page.options["zy"]?.last?.label, "金融学")
        XCTAssertEqual(page.fields["__VIEWSTATE"], "state+1=")
        XCTAssertEqual(page.fields["__EVENTVALIDATION"], "token+two")
        XCTAssertEqual(page.report?.courses.count, 1)
        XCTAssertTrue(page.report?.practice?.contains("专业实习") == true)
        XCTAssertTrue(page.report?.adjustments.contains("调课说明") == true)
    }
    func testCompactWeeksAndMultipleCoursesRenderInExistingViews() throws {
        let report = try XCTUnwrap(HTMLParser.professional(professionalHTML()).report)
        let beginning = SchoolSchedule.date(2026, 8, 31)
        func lessons(_ week: Int) -> [Lesson] { SchoolSchedule.lessons(report: report, on: beginning.addingTimeInterval(Double((week - 1) * 7 * 86400)), beginning: beginning) }
        XCTAssertEqual(lessons(7).map(\.name), ["微观经济学"])
        XCTAssertEqual(Set(lessons(8).map(\.room)), Set(["田604", "诚A601"]))
        XCTAssertTrue(lessons(13).isEmpty)
        XCTAssertEqual(lessons(15).first?.room, "田604")
        XCTAssertEqual(lessons(8).first?.end.timeIntervalSince(lessons(8).first!.start), 95 * 60)
    }
    func testCacheExcludesSessionAndFormState() throws {
        let item = try SavedProfessionalTimetable(page: HTMLParser.professional(professionalHTML()))
        let data = try JSONEncoder().encode(item)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("VIEWSTATE")); XCTAssertFalse(text.contains("EVENTVALIDATION"))
        XCTAssertFalse(text.contains("tjkbcx.aspx"))
        XCTAssertEqual(try JSONDecoder().decode(SavedProfessionalTimetable.self, from: data).selection, item.selection)
    }
    func testMissingSelectorsAndExpiredSessionAreRejected() {
        XCTAssertThrowsError(try HTMLParser.professional("<form></form>"))
        XCTAssertThrowsError(try HTMLParser.professional("<input name='txtUserName'>")) { XCTAssertEqual($0 as? CampusError, .sessionExpired) }
    }
    func testSequentialPostbackRefreshesHiddenState() async throws {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [ProfessionalProtocol.self]
        let client = AcademicClient(configuration: config)
        try await client.restore(SavedSession(baseURL: URL(string: "http://jwgl.fafu.edu.cn/(abcdefghijklmnopqrstuvwx)/")!, student: Student(account: "test", name: "测试"), cookies: []))
        let first = try await client.professionalPage()
        XCTAssertEqual(first.fields["__VIEWSTATE"], "old+state=")
        let next = try await client.professionalPage(changing: "zy", value: "6304")
        XCTAssertEqual(next.fields["__VIEWSTATE"], "new-state")
        do { _ = try await client.professionalPage(changing: "kb", value: "invented"); XCTFail("Invalid option must not be posted") } catch {}
    }
}
