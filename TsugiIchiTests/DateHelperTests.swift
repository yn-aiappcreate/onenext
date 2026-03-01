import XCTest
@testable import TsugiIchi

final class DateHelperTests: XCTestCase {

    func testWeekIdFormat() {
        let weekId = DateHelper.weekId()
        XCTAssertTrue(weekId.contains("-W"))
        XCTAssertEqual(weekId.count, 8)
    }

    func testWeekIdForKnownDate() {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 5
        let calendar = Calendar(identifier: .iso8601)
        guard let date = calendar.date(from: components) else {
            XCTFail("Failed to create date")
            return
        }
        let weekId = DateHelper.weekId(for: date)
        XCTAssertEqual(weekId, "2026-W02")
    }

    func testStartOfWeekIsMonday() {
        let start = DateHelper.startOfWeek()
        let calendar = Calendar(identifier: .iso8601)
        let weekday = calendar.component(.weekday, from: start)
        XCTAssertEqual(weekday, 2)
    }
}
