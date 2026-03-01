import XCTest
@testable import TsugiIchi

final class GoalModelTests: XCTestCase {

    func testGoalDefaults() {
        let goal = Goal(title: "Test Goal")
        XCTAssertEqual(goal.title, "Test Goal")
        XCTAssertNil(goal.category)
        XCTAssertEqual(goal.priority, .medium)
        XCTAssertNil(goal.dueDate)
        XCTAssertNil(goal.note)
        XCTAssertNil(goal.imageData)
        XCTAssertEqual(goal.status, .active)
        XCTAssertTrue(goal.steps.isEmpty)
    }

    func testGoalFullInit() {
        let date = Date()
        let goal = Goal(
            title: "旅行に行く",
            category: .travel,
            priority: .high,
            dueDate: date,
            note: "メモ"
        )
        XCTAssertEqual(goal.title, "旅行に行く")
        XCTAssertEqual(goal.category, .travel)
        XCTAssertEqual(goal.priority, .high)
        XCTAssertEqual(goal.dueDate, date)
        XCTAssertEqual(goal.note, "メモ")
        XCTAssertEqual(goal.status, .active)
    }
}

final class StepModelTests: XCTestCase {

    func testStepDefaults() {
        let step = Step(title: "Test Step")
        XCTAssertEqual(step.title, "Test Step")
        XCTAssertEqual(step.durationMin, 30)
        XCTAssertEqual(step.type, .auto)
        XCTAssertEqual(step.status, .pending)
        XCTAssertEqual(step.sortOrder, 0)
        XCTAssertNil(step.scheduledAt)
        XCTAssertNil(step.goal)
    }
}

final class GoalCategoryTests: XCTestCase {

    func testAllCategoriesHaveSystemImages() {
        for category in GoalCategory.allCases {
            XCTAssertFalse(category.systemImage.isEmpty)
        }
    }

    func testCategoryCount() {
        XCTAssertEqual(GoalCategory.allCases.count, 5)
    }
}

final class GoalPriorityTests: XCTestCase {

    func testPriorityOrdering() {
        XCTAssertTrue(GoalPriority.low < GoalPriority.medium)
        XCTAssertTrue(GoalPriority.medium < GoalPriority.high)
    }

    func testPriorityLabels() {
        for priority in GoalPriority.allCases {
            XCTAssertFalse(priority.label.isEmpty)
        }
    }
}
