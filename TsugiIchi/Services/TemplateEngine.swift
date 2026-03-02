import Foundation

/// Template-based Step generation (fixed logic, no AI/LLM).
/// Each GoalCategory maps to a predefined list of StepTemplates.
struct TemplateEngine {

    struct StepTemplate {
        let title: String
        let durationMin: Int
    }

    /// Returns predefined step templates for the given category.
    static func templates(for category: GoalCategory) -> [StepTemplate] {
        switch category {
        case .travel:
            return [
                StepTemplate(title: String(localized: "行き先をリストアップ"), durationMin: 15),
                StepTemplate(title: String(localized: "日程を決める"), durationMin: 10),
                StepTemplate(title: String(localized: "宿泊先を調べる"), durationMin: 30),
                StepTemplate(title: String(localized: "交通手段を調べる"), durationMin: 20),
                StepTemplate(title: String(localized: "持ち物リストを作る"), durationMin: 15),
                StepTemplate(title: String(localized: "予約する"), durationMin: 30),
            ]
        case .event:
            return [
                StepTemplate(title: String(localized: "日程を決める"), durationMin: 10),
                StepTemplate(title: String(localized: "場所を決める"), durationMin: 15),
                StepTemplate(title: String(localized: "参加者に連絡する"), durationMin: 15),
                StepTemplate(title: String(localized: "必要なものを準備する"), durationMin: 30),
                StepTemplate(title: String(localized: "当日の流れを確認する"), durationMin: 15),
            ]
        case .learning:
            return [
                StepTemplate(title: String(localized: "教材を選ぶ"), durationMin: 20),
                StepTemplate(title: String(localized: "学習計画を立てる"), durationMin: 15),
                StepTemplate(title: String(localized: "第1回の学習をする"), durationMin: 60),
                StepTemplate(title: String(localized: "復習する"), durationMin: 30),
                StepTemplate(title: String(localized: "アウトプットする"), durationMin: 45),
            ]
        case .health:
            return [
                StepTemplate(title: String(localized: "現状を記録する"), durationMin: 10),
                StepTemplate(title: String(localized: "目標値を決める"), durationMin: 10),
                StepTemplate(title: String(localized: "メニューを決める"), durationMin: 15),
                StepTemplate(title: String(localized: "初回を実行する"), durationMin: 30),
                StepTemplate(title: String(localized: "1週間の振り返りをする"), durationMin: 15),
            ]
        case .hobby:
            return [
                StepTemplate(title: String(localized: "必要な道具を調べる"), durationMin: 15),
                StepTemplate(title: String(localized: "道具を準備する"), durationMin: 30),
                StepTemplate(title: String(localized: "初回をやってみる"), durationMin: 60),
            ]
        }
    }

    /// Generates Step objects from templates and attaches them to the given Goal.
    @discardableResult
    static func generateSteps(for goal: Goal, category: GoalCategory) -> [Step] {
        let stepTemplates = templates(for: category)
        var steps: [Step] = []
        for (index, template) in stepTemplates.enumerated() {
            let step = Step(
                title: template.title,
                durationMin: template.durationMin,
                type: .auto,
                sortOrder: index
            )
            steps.append(step)
        }
        goal.steps = steps
        return steps
    }
}
