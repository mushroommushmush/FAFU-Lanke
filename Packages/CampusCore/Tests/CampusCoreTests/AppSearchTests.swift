import XCTest
@testable import CampusCore
final class AppSearchTests: XCTestCase {
    func testSearchesAllRecordFieldsAndFeatureAliases() {
        var snapshot = CampusSnapshot(student: Student(account: "12345", name: "测试同学"))
        let options = PageOptions(years: [], terms: [], selected: Semester(year: "", term: ""))
        snapshot.grades = RecordsReport(records: [TableRecord(id: "1", fields: [
            TableField(label: "课程名称", value: "财政学"), TableField(label: "成绩", value: "92"), TableField(label: "任课教师", value: "张老师")])], options: options)
        let entries = AppSearchIndex.entries(snapshot: snapshot, manual: [])
        XCTAssertEqual(entries.filter { $0.matches("财政 张老师") }.count, 1)
        XCTAssertEqual(entries.first { $0.matches("自动登录") }?.route, "account")
        XCTAssertEqual(entries.first { $0.matches("列表 表格") }?.route, "schedule")
        XCTAssertEqual(entries.filter { $0.matches("不存在的信息") }.count, 0)
    }
    func testCaseInsensitiveRoomSearchAndHiddenManualCourse() {
        let student = Student(account: "12345", name: "测试同学")
        let lesson = Lesson(id: "a", name: "自习", room: "诚A601", start: Date(), end: Date().addingTimeInterval(2700))
        let visible = AppSearchIndex.entries(snapshot: CampusSnapshot(student: student), manual: [lesson])
        XCTAssertEqual(visible.filter { $0.matches("a601") }.count, 1)
        let hidden = AppSearchIndex.entries(snapshot: CampusSnapshot(student: student), manual: [lesson], hidden: ["a"])
        XCTAssertFalse(hidden.contains { $0.route == "manual" })
    }
    func testNoSnapshotDoesNotExposePreviousAccountsManualData() {
        let lesson = Lesson(id: "a", name: "私人课程", room: "创211", start: Date(), end: Date().addingTimeInterval(2700))
        let entries = AppSearchIndex.entries(snapshot: nil, manual: [lesson])
        XCTAssertTrue(entries.allSatisfy { $0.category == "功能" })
        XCTAssertFalse(entries.contains { $0.matches("私人课程") })
    }
}
