import XCTest
@testable import CampusCore

final class ParserTests: XCTestCase {
    private func fixture(_ name: String) throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "html"))
        return try String(contentsOf: url, encoding: .utf8)
    }
    func testHiddenFieldsPreserveViewStateAndEntities() throws {
        let fields = try HTMLParser.hiddenFields(fixture("login"))
        XCTAssertEqual(fields["__VIEWSTATE"], "a+b/c==&v=1")
        XCTAssertEqual(fields["__EVENTVALIDATION"], "second-page-value")
        XCTAssertNil(fields["TextBox2"])
    }
    func testStudentRoleUsesLiveFormValue() throws {
        let fields = try HTMLParser.loginFields(fixture("login"))
        XCTAssertEqual(fields["RadioButtonList1"], "学生")
        XCTAssertEqual(fields["Button1"], "登录")
    }
    func testLoginPageIsNeverAcceptedAsAnEmptyGradeReport() throws {
        XCTAssertThrowsError(try HTMLParser.records(fixture("login"), page: "成绩")) {
            XCTAssertEqual($0 as? CampusError, .sessionExpired)
        }
    }
    func testLoginNameMustBePresent() throws {
        XCTAssertEqual(try HTMLParser.studentName("<span id='xhxm'>示例同学</span>"), "示例")
        XCTAssertNil(try HTMLParser.studentName("<p>欢迎访问</p>"))
    }
    func testAlertIsTextOnlyAndPreserved() {
        XCTAssertEqual(HTMLParser.alertMessage("<script>alert('验证码不正确');</script>"), "验证码不正确")
    }
    func testGradesPreserveTextualMarksAndMakeupValues() throws {
        let report = try HTMLParser.records(fixture("grades"), page: "成绩")
        XCTAssertEqual(report.records.count, 2)
        XCTAssertEqual(report.records[0].title, "植物学 & 实验")
        XCTAssertEqual(report.records[0].value(["成绩"]), "优秀")
        XCTAssertEqual(report.records[1].value(["补考成绩"]), "补考中")
    }
    func testUnknownHTMLFailsInsteadOfOverwritingCacheWithEmptyResults() {
        XCTAssertThrowsError(try HTMLParser.records("<h1>系统维护</h1>", page: "成绩"))
        XCTAssertThrowsError(try HTMLParser.timetable("<h1>系统维护</h1>"))
    }
    func testExplicitEmptyResultsAreAllowed() throws {
        let report = try HTMLParser.records("<p>暂无考试安排</p>", page: "考试")
        XCTAssertTrue(report.records.isEmpty)
    }
    func testChangedRecordColumnsAreNotSilentlyDropped() {
        let html = "<table id='Datagrid1'><tr><td>课程名称</td><td>成绩</td></tr><tr><td>课程</td><td>80</td><td>新增列</td></tr></table>"
        XCTAssertThrowsError(try HTMLParser.records(html, page: "成绩"))
    }
    func testTimetableExpandsRowspanAndColspanWithoutDuplicateCourses() throws {
        let report = try HTMLParser.timetable(fixture("timetable"))
        let monday = report.courses.filter { $0.weekday == 1 }
        XCTAssertEqual(monday.count, 1)
        XCTAssertTrue(monday[0].period.contains("第1节"))
        XCTAssertTrue(monday[0].period.contains("第2节"))
        XCTAssertTrue(monday[0].content.contains("单周"))
        XCTAssertEqual(report.courses.first { $0.weekday == 2 }?.content.components(separatedBy: "\n").first, "英语")
        XCTAssertTrue(report.adjustments.contains("第3周停课"))
    }
    func testTimetableRejectsUnrecognizedWeekdayColumns() {
        XCTAssertThrowsError(try HTMLParser.timetable("<table id='Table1'><tr><td>新格式</td></tr></table>"))
    }
    func testSelectedSemesterUsesValuesNotCurrentCalendar() throws {
        let result = try HTMLParser.options(fixture("timetable"))
        XCTAssertEqual(result.selected, Semester(year: "2026-2027", term: "1"))
        XCTAssertEqual(result.years.count, 2)
    }
    func testExamKeepsPendingTimeInsteadOfInventingDate() throws {
        let report = try HTMLParser.records(fixture("exams"), page: "考试")
        XCTAssertEqual(report.records.first?.value(["考试时间"]), "待安排")
    }
    func testGBKFormEncodingEscapesChineseAndReservedCharacters() throws {
        XCTAssertEqual(try LegacyEncoding.component("学生 &+="), "%D1%A7%C9%FA+%26%2B%3D")
        let body = try LegacyEncoding.form(["__VIEWSTATE": "a+b/c=="])
        XCTAssertEqual(String(data: body, encoding: .utf8), "__VIEWSTATE=a%2Bb%2Fc%3D%3D")
    }
    func testChineseAndUTF8ResponseDecoding() throws {
        XCTAssertEqual(try LegacyEncoding.decode(Data([0xD1, 0xA7, 0xC9, 0xFA]), charset: "gb2312"), "学生")
        XCTAssertEqual(try LegacyEncoding.decode(Data("课程".utf8)), "课程")
    }
    func testCredentialsCannotBeRedirectedOutsideSchoolHost() {
        XCTAssertTrue(AcademicClient.isAllowed(URL(string: "http://jwgl.fafu.edu.cn/(abc)/default2.aspx")))
        for value in ["https://jwgl.fafu.edu.cn.evil.example/", "https://api.ifafu.cn/", "ftp://jwgl.fafu.edu.cn/", "http://user:pass@jwgl.fafu.edu.cn/", "http://jwgl.fafu.edu.cn:8080/"] {
            XCTAssertFalse(AcademicClient.isAllowed(URL(string: value)))
        }
    }
    func testSnapshotRoundTripContainsOnlyRecordsAndStudentIdentity() throws {
        var snapshot = CampusSnapshot(student: Student(account: "test-student", name: "示例"))
        snapshot.grades = try HTMLParser.records(fixture("grades"), page: "成绩")
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(CampusSnapshot.self, from: data)
        XCTAssertEqual(decoded.student, snapshot.student)
        XCTAssertEqual(decoded.grades?.records.count, 2)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(object["password"]); XCTAssertNil(object["cookie"]); XCTAssertNil(object["token"])
    }
}
