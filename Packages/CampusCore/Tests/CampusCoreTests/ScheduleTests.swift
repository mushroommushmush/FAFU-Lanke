import XCTest
@testable import CampusCore

final class ScheduleTests: XCTestCase {
    func testClassroomIgnoresChangeIdentifiers() {
        XCTAssertEqual(SchoolSchedule.classroom(in: ["教师", "禧 103", "(换0420)"]), "禧103")
        XCTAssertEqual(SchoolSchedule.classroom(in: ["教师", "禧103", "(换0410)、(换0369)"]), "禧103")
        XCTAssertEqual(SchoolSchedule.classroom(in: ["教师", "桃1-137"]), "桃1-137")
        XCTAssertEqual(SchoolSchedule.classroom(in: ["教师", "(换0420)"]), "")
    }
    func testLetteredClassrooms() {
        XCTAssertEqual(SchoolSchedule.classroom(in: ["教师", "诚A601", "(换0420)"]), "诚A601")
        XCTAssertEqual(SchoolSchedule.classroom(in: ["教师", "诚 B 402"]), "诚B402")
        XCTAssertEqual(SchoolSchedule.classroom(in: ["教师", "创211"]), "创211")
    }
    func testRelativeUpdateAge() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        XCTAssertEqual(SchoolSchedule.updateAge(now.addingTimeInterval(-120), now: now), "更新于2分钟前")
        XCTAssertEqual(SchoolSchedule.updateAge(now.addingTimeInterval(-86400), now: now), "更新于1天前")
        XCTAssertEqual(SchoolSchedule.updateAge(now.addingTimeInterval(-31 * 86400), now: now), "更新于很久之前")
        XCTAssertEqual(SchoolSchedule.updateAge(now.addingTimeInterval(60), now: now), "更新于0分钟前")
    }
    func testWeekAndTimezone() {
        XCTAssertEqual(SchoolSchedule.week(on: SchoolSchedule.date(2026, 10, 31), beginning: SchoolSchedule.date(2026, 8, 31)), 9)
        XCTAssertEqual(SchoolSchedule.week(on: SchoolSchedule.date(2026, 8, 30), beginning: SchoolSchedule.date(2026, 8, 31)), 0)
    }
    func testWeekRestrictions() {
        XCTAssertTrue(SchoolSchedule.includes(week: 9, text: "周五第1,2节{第2-12周}单周"))
        XCTAssertFalse(SchoolSchedule.includes(week: 8, text: "第2-12周单周"))
        XCTAssertFalse(SchoolSchedule.includes(week: 9, text: "第14-15周"))
        XCTAssertFalse(SchoolSchedule.includes(week: 9, text: "未知周次"))
        XCTAssertFalse(SchoolSchedule.includes(week: 9, text: "第15-2周"))
    }
    func testSeparatesCoursesAndFiltersByWeek() throws {
        let cell = CourseCell(id: "one", weekday: 5, period: "第1节 · 第2节", content: "计量经济学\n周五第1,2节{第14-15周}\n教师\n禧501\n计量经济学\n周五第1,2节{第2-12周}\n教师\n田202")
        let report = TimetableReport(courses: [cell], adjustments: "", options: PageOptions(years: [], terms: [], selected: Semester(year: "2026-2027", term: "1")))
        let courses = SchoolSchedule.lessons(report: report, on: SchoolSchedule.date(2026, 10, 30), beginning: SchoolSchedule.date(2026, 8, 31))
        XCTAssertEqual(courses.count, 1)
        let course = try XCTUnwrap(courses.first)
        XCTAssertEqual(course.name, "计量经济学")
        XCTAssertEqual(course.room, "田202")
        XCTAssertEqual(course.end.timeIntervalSince(course.start), 95 * 60)
        XCTAssertTrue(SchoolSchedule.lessons(report: report, on: SchoolSchedule.date(2026, 10, 31), beginning: SchoolSchedule.date(2026, 8, 31)).isEmpty)
    }
    func testPhaseBoundaries() {
        let start = SchoolSchedule.date(2026, 10, 31)
        let lesson = Lesson(name: "课程", room: "创211", start: start, end: start.addingTimeInterval(2700))
        XCTAssertEqual(lesson.phase(at: start.addingTimeInterval(-901)), .upcoming)
        XCTAssertEqual(lesson.phase(at: start.addingTimeInterval(-900)), .soon)
        XCTAssertEqual(lesson.phase(at: start), .active)
        XCTAssertEqual(lesson.phase(at: lesson.end), .ended)
    }
    func testManualCourseRoundTrip() throws {
        let lesson = Lesson(name: "研讨", room: "创211", start: Date(), end: Date().addingTimeInterval(2700))
        XCTAssertEqual(try JSONDecoder().decode(Lesson.self, from: JSONEncoder().encode(lesson)), lesson)
    }
}
