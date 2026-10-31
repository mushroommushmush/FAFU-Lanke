import XCTest
@testable import CampusCore
final class ElectiveTests: XCTestCase {
    func testPreservesFirstRowAndFractionalCredits() throws {
        let html = "<table id='DataGrid5'><tr><td>艺术、体育类 2.5</td><td>自然科学类 3</td></tr></table><table id='DataGrid4'><tr><td>任意选修课 8</td></tr></table>"
        let result = try HTMLParser.electives(html)
        XCTAssertEqual(result.records.count, 2)
        XCTAssertEqual(result.records[0].fields[0].value, "艺术、体育类 2.5")
        XCTAssertEqual(result.records[1].fields[0].value, "任意选修课 8")
    }
    func testMissingTableIsNotZeroCredits() {
        XCTAssertThrowsError(try HTMLParser.electives("<p>学校维护中</p>"))
    }
    func testExpiredLoginIsRejected() {
        XCTAssertThrowsError(try HTMLParser.electives("<input name='txtUserName'><table id='DataGrid5'></table>")) { error in
            XCTAssertEqual(error as? CampusError, .sessionExpired)
        }
    }
    func testOldSnapshotRemainsReadable() throws {
        let data = Data(#"{"schemaVersion":1,"student":{"account":"123","name":"测试"}}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(CampusSnapshot.self, from: data).electives)
    }
}
