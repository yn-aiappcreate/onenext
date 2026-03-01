import XCTest
@testable import OneNext

final class TemplateEngineTests: XCTestCase {

    func testEachCategoryGenerates3To8Templates() {
        for category in GoalCategory.allCases {
            let templates = TemplateEngine.templates(for: category)
            XCTAssertGreaterThanOrEqual(templates.count, 3,
                "Category \(category.rawValue) should have >= 3 templates")
            XCTAssertLessThanOrEqual(templates.count, 8,
                "Category \(category.rawValue) should have <= 8 templates")
        }
    }

    func testTemplatesHaveNonEmptyTitles() {
        for category in GoalCategory.allCases {
            let templates = TemplateEngine.templates(for: category)
            for template in templates {
                XCTAssertFalse(template.title.isEmpty)
            }
        }
    }

    func testTemplatesHavePositiveDurations() {
        for category in GoalCategory.allCases {
            let templates = TemplateEngine.templates(for: category)
            for template in templates {
                XCTAssertGreaterThan(template.durationMin, 0)
            }
        }
    }

    func testGenerateStepsCreatesAndAttachesToGoal() {
        let goal = Goal(title: "旅行テスト", category: .travel)
        let steps = TemplateEngine.generateSteps(for: goal, category: .travel)
        let expectedCount = TemplateEngine.templates(for: .travel).count

        XCTAssertEqual(steps.count, expectedCount)
        XCTAssertEqual(goal.steps.count, expectedCount)

        for (index, step) in steps.enumerated() {
            XCTAssertEqual(step.type, .auto)
            XCTAssertEqual(step.status, .pending)
            XCTAssertEqual(step.sortOrder, index)
        }
    }

    func testTravelTemplatesAreCorrect() {
        let templates = TemplateEngine.templates(for: .travel)
        XCTAssertEqual(templates.count, 6)
        XCTAssertEqual(templates[0].title, "行き先をリストアップ")
    }
}
