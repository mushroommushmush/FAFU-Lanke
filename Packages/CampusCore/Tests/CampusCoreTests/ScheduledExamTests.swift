import XCTest
@testable import CampusCore

final class ScheduledExamTests: XCTestCase {
    private func record(_ time: String) -> TableRecord {
        TableRecord(id: "row-1", fields: [
            TableField(label: "课程名称", value: "高等数学"),
            TableField(label: "考试时间", value: time),
            TableField(label: "考试教室", value: "田611")
        ])
    }

    func testSchoolExamDateAndRoom() throws {
        let exam = try XCTUnwrap(ScheduledExam(record: record("2025年05月10日 (18:30-20:30)")))
        let midnight = SchoolSchedule.date(2025, 5, 10)
        XCTAssertEqual(exam.slot.start, midnight.addingTimeInterval(1110 * 60))
        XCTAssertEqual(exam.slot.end, midnight.addingTimeInterval(1230 * 60))
        XCTAssertEqual(exam.slot.room, "田611")
    }

    func testExtendedGridPlacesLateExamWithinItsDay() throws {
        let exam = try XCTUnwrap(ScheduledExam(record: record("2026-11-10 20:30–21:30")))
        let day = SchoolSchedule.date(2026, 11, 10)
        let starts = SchoolSchedule.starts + [1250]
        let start = SchoolSchedule.gridPosition(minute: exam.slot.start.timeIntervalSince(day) / 60, starts: starts, endMinute: 1290)
        let end = SchoolSchedule.gridPosition(minute: exam.slot.end.timeIntervalSince(day) / 60, starts: starts, endMinute: 1290)
        XCTAssertLessThan(start, 12)
        XCTAssertEqual(end, 13)
    }

    func testUnscheduledAndInvalidTimesAreNotPlaced() {
        for time in ["待安排", "2026-11-10", "2026-02-30 09:00-11:00", "2026-11-10 11:00-09:00"] {
            XCTAssertNil(ScheduledExam(record: record(time)))
        }
    }
}
