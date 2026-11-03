import XCTest
@testable import CampusCore
final class ShortCourseTests: XCTestCase {
    func testLunchAndEveningBreakShortCoursesHavePositiveHeight() {
        for (start, end) in [(720.0, 740.0), (1070, 1080), (485, 490)] {
            XCTAssertGreaterThan(SchoolSchedule.gridPosition(minute: end, starts: SchoolSchedule.starts), SchoolSchedule.gridPosition(minute: start, starts: SchoolSchedule.starts))
        }
    }
    func testPeriodAnchorsAndLastPeriod() {
        for (i, time) in SchoolSchedule.starts.enumerated() {
            XCTAssertEqual(SchoolSchedule.gridPosition(minute: Double(time), starts: SchoolSchedule.starts), Double(i))
        }
        XCTAssertEqual(SchoolSchedule.gridPosition(minute: 1250, starts: SchoolSchedule.starts), 12)
    }
}
