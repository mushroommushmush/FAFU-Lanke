import XCTest
@testable import CampusCore

final class PeriodSelectionTests: XCTestCase {
    func testSelectionResolvesOnChosenDate() throws {
        let date = SchoolSchedule.date(2026, 11, 3)
        let interval = try XCTUnwrap(SchoolSchedule.interval(on: date, periods: [6, 7]))
        XCTAssertEqual(interval.start, date.addingTimeInterval(14 * 3600))
        XCTAssertEqual(interval.end, date.addingTimeInterval(15 * 3600 + 35 * 60))
    }
    func testSinglePeriodAndCustomTimes() throws {
        let date = SchoolSchedule.date(2026, 11, 4)
        let interval = try XCTUnwrap(SchoolSchedule.interval(on: date, periods: [2], starts: [500, 560]))
        XCTAssertEqual(interval.start, date.addingTimeInterval(560 * 60))
        XCTAssertEqual(interval.duration, 45 * 60)
    }
    func testGappedSelectionUsesFirstAndLast() throws {
        let date = SchoolSchedule.date(2026, 11, 3)
        let interval = try XCTUnwrap(SchoolSchedule.interval(on: date, periods: [3, 5]))
        XCTAssertEqual(interval.start, date.addingTimeInterval(595 * 60))
        XCTAssertEqual(interval.end, date.addingTimeInterval(740 * 60))
    }
    func testInvalidSelectionCannotSave() {
        let date = SchoolSchedule.date(2026, 11, 3)
        XCTAssertNil(SchoolSchedule.interval(on: date, periods: []))
        XCTAssertNil(SchoolSchedule.interval(on: date, periods: [0]))
        XCTAssertNil(SchoolSchedule.interval(on: date, periods: [13]))
    }
}
