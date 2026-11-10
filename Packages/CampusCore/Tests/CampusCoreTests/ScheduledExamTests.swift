import XCTest
@testable import CampusCore

final class ScheduledExamTests: XCTestCase {
    func testCountdownBoundariesAndCompletedExam() throws {
        let exam = try XCTUnwrap(ScheduledExam(record: record("2026-11-10 09:00-11:00")))
        for (seconds, expected) in [(90000.0, "1天1小时"), (86400, "1天0小时"), (86399, "23小时59分钟"), (3600, "1小时0分钟"), (3599, "60分钟"), (61, "2分钟"), (1, "1分钟")] {
            XCTAssertEqual(exam.countdown(at: exam.slot.start.addingTimeInterval(-seconds)), expected)
        }
        XCTAssertEqual(exam.countdown(at: exam.slot.start), "考试中")
        XCTAssertEqual(exam.countdown(at: exam.slot.end), "已结束")
    }

    func testScoreOrderingIsNumericStableAndUnknownLast() {
        let scores = ["96", "9", "及格", "78.8", "96"]
        let records = scores.enumerated().map { TableRecord(id: "\($0.offset)", fields: [TableField(label: "成绩", value: $0.element)]) }
        XCTAssertEqual(RecordOrdering.sorted(records, byScore: true, ascending: true).map(\.id), ["1", "3", "0", "4", "2"])
        XCTAssertEqual(RecordOrdering.sorted(records, byScore: true, ascending: false).map(\.id), ["0", "4", "3", "1", "2"])
    }

    func testExamOrderingUsesDateNotDisplayText() {
        let records = [record("2026年12月2日 (09:00-11:00)"), record("待定"), record("2026年2月12日 (09:00-11:00)")]
        let sorted = RecordOrdering.sorted(records, byScore: false, ascending: true)
        XCTAssertEqual(sorted.first?.value(["考试时间"]), "2026年2月12日 (09:00-11:00)")
        XCTAssertEqual(sorted.last?.value(["考试时间"]), "待定")
        XCTAssertEqual(RecordOrdering.sorted(records, byScore: false, ascending: false).first?.value(["考试时间"]), "2026年12月2日 (09:00-11:00)")
    }
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
