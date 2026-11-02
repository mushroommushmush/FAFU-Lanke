import XCTest
@testable import CampusCore

final class CourseGridLayoutTests: XCTestCase {
    private func lesson(_ id: String, _ start: Int, _ end: Int) -> Lesson {
        let date = SchoolSchedule.date(2026, 11, 4)
        return Lesson(id: id, name: id, room: "田611", start: date.addingTimeInterval(Double(start) * 60), end: date.addingTimeInterval(Double(end) * 60))
    }
    func testSeparateTimeGroupsKeepFullWidthAfterConflict() {
        let items = [lesson("a", 480, 575), lesson("b", 530, 575), lesson("c", 840, 935), lesson("d", 950, 995)]
        let layout = CourseGridLayout.placements(items)
        XCTAssertEqual(layout["a"]?.columns, 2)
        XCTAssertEqual(layout["b"]?.columns, 2)
        XCTAssertEqual(layout["c"]?.columns, 1)
        XCTAssertEqual(layout["c"]?.column, 0)
        XCTAssertEqual(layout["d"]?.columns, 1)
    }
    func testThreeNonOverlappingCoursesAllFillTheirColumn() {
        let layout = CourseGridLayout.placements([lesson("a", 595, 690), lesson("b", 840, 935), lesson("c", 950, 995)])
        XCTAssertTrue(layout.values.allSatisfy { $0.column == 0 && $0.columns == 1 })
    }
    func testTouchingBoundariesDoNotConflictAndNestedClassesStayVisible() {
        let layout = CourseGridLayout.placements([lesson("a", 480, 600), lesson("b", 480, 530), lesson("c", 530, 600), lesson("d", 600, 645)])
        XCTAssertEqual(layout["b"]?.column, layout["c"]?.column)
        XCTAssertNotEqual(layout["a"]?.column, layout["b"]?.column)
        XCTAssertEqual(layout["d"]?.columns, 1)
    }
    func testDuplicateIdentifiersDoNotCreatePhantomHalfWidthCards() {
        let item = lesson("a", 595, 690)
        XCTAssertEqual(CourseGridLayout.unique([item, item]).count, 1)
        XCTAssertEqual(CourseGridLayout.placements([item, item])["a"]?.columns, 1)
    }
}
