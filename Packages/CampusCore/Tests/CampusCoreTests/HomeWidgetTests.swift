import XCTest
@testable import CampusCore

final class HomeWidgetTests: XCTestCase {
    private let day = SchoolSchedule.date(2026, 10, 31)
    private func lesson(_ id: String, _ start: TimeInterval, _ end: TimeInterval) -> HomeWidgetLesson {
        HomeWidgetLesson(id: id, name: "课程", room: "诚A601", start: day.addingTimeInterval(start), end: day.addingTimeInterval(end))
    }
    func testNextLessonChangesAtEndBoundary() {
        let first = lesson("1", 8*3600, 9*3600)
        let second = lesson("2", 10*3600, 11*3600)
        let packet = HomeWidgetSnapshot(lessons: [second, first], sourceUpdatedAt: day)
        XCTAssertEqual(packet.next(at: day.addingTimeInterval(8*3600))?.id, "1")
        XCTAssertEqual(packet.next(at: day.addingTimeInterval(9*3600))?.id, "2")
        XCTAssertNil(packet.next(at: day.addingTimeInterval(11*3600)))
    }
    func testTomorrowDoesNotAppearAsToday() {
        let packet = HomeWidgetSnapshot(lessons: [lesson("1", 86400+8*3600, 86400+9*3600)], sourceUpdatedAt: nil)
        XCTAssertTrue(packet.today(at: day).isEmpty)
        XCTAssertNil(packet.next(at: day))
    }
    func testTimelineHasClassAndMidnightBoundaries() {
        let first = lesson("1", 8*3600, 9*3600)
        let packet = HomeWidgetSnapshot(lessons: [first], sourceUpdatedAt: day)
        let dates = packet.timelineDates(after: day)
        for date in [first.start.addingTimeInterval(-900), first.start, first.end, day.addingTimeInterval(86400)] {
            XCTAssertTrue(dates.contains(date))
        }
        XCTAssertEqual(dates, Array(Set(dates)).sorted())
    }
    func testPayloadContainsOnlyWidgetSummary() throws {
        let packet = HomeWidgetSnapshot(lessons: [lesson("1", 8*3600, 9*3600)], sourceUpdatedAt: day)
        let data = try JSONEncoder().encode(packet)
        XCTAssertEqual(try JSONDecoder().decode(HomeWidgetSnapshot.self, from: data), packet)
        let text = String(decoding: data, as: UTF8.self)
        for name in ["password", "cookie", "student", "account"] { XCTAssertFalse(text.contains(name)) }
    }
}
