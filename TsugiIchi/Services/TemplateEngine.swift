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
                StepTemplate(title: "行き先をリストアップ", durationMin: 15),
                StepTemplate(title: "日程を決める", durationMin: 10),
                StepTemplate(title: "宿泊先を調べる", durationMin: 30),
                StepTemplate(title: "交通手段を調べる", durationMin: 20),
                StepTemplate(title: "持ち物リストを作る", durationMin: 15),
                StepTemplate(title: "予約する", durationMin: 30),
            ]
        case .event:
            return [
                StepTemplate(title: "日程を決める", durationMin: 10),
                StepTemplate(title: "場所を決める", durationMin: 15),
                StepTemplate(title: "参加者に連絡する", durationMin: 15),
                StepTemplate(title: "必要なものを準備する", durationMin: 30),
                StepTemplate(title: "当日の流れを確認する", durationMin: 15),
            ]
        case .learning:
            return [
                StepTemplate(title: "教材を選ぶ", durationMin: 20),
                StepTemplate(title: "学習計画を立てる", durationMin: 15),
                StepTemplate(title: "第1回の学習をする", durationMin: 60),
                StepTemplate(title: "復習する", durationMin: 30),
                StepTemplate(title: "アウトプットする", durationMin: 45),
            ]
        case .health:
            return [
                StepTemplate(title: "現状を記録する", durationMin: 10),
                StepTemplate(title: "目標値を決める", durationMin: 10),
                StepTemplate(title: "メニューを決める", durationMin: 15),
                StepTemplate(title: "初回を実行する", durationMin: 30),
                StepTemplate(title: "1週間の振り返りをする", durationMin: 15),
            ]
        case .hobby:
            return [
                StepTemplate(title: "必要な道具を調べる", durationMin: 15),
                StepTemplate(title: "道具を準備する", durationMin: 30),
                StepTemplate(title: "初回をやってみる", durationMin: 60),
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
