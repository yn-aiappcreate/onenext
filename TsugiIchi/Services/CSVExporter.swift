import Foundation

/// Goal/Step データを CSV 形式でエクスポートするユーティリティ。
enum CSVExporter {

    /// Goal 一覧の CSV 文字列を生成
    static func exportGoals(_ goals: [Goal]) -> String {
        var rows: [String] = []
        rows.append("Goal ID,タイトル,カテゴリ,優先度,ステータス,期限,作成日,Step数,完了Step数")
        for goal in goals {
            let id = goal.id.uuidString
            let title = escape(goal.title)
            let category = goal.category?.rawValue ?? ""
            let priority = goal.priority.label
            let status = goal.status.rawValue
            let dueDate = goal.dueDate.map { formatDate($0) } ?? ""
            let createdAt = formatDate(goal.createdAt)
            let stepCount = goal.steps.count
            let doneCount = goal.steps.filter { $0.status == .done }.count
            rows.append("\(id),\(title),\(category),\(priority),\(status),\(dueDate),\(createdAt),\(stepCount),\(doneCount)")
        }
        return rows.joined(separator: "\n")
    }

    /// Step 一覧の CSV 文字列を生成
    static func exportSteps(_ goals: [Goal]) -> String {
        var rows: [String] = []
        rows.append("Step ID,Goal,タイトル,所要時間(分),タイプ,ステータス,予定日")
        for goal in goals {
            for step in goal.steps.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                let id = step.id.uuidString
                let goalTitle = escape(goal.title)
                let title = escape(step.title)
                let duration = step.durationMin
                let type = step.type.rawValue
                let status = step.status.rawValue
                let scheduled = step.scheduledAt.map { formatDate($0) } ?? ""
                rows.append("\(id),\(goalTitle),\(title),\(duration),\(type),\(status),\(scheduled)")
            }
        }
        return rows.joined(separator: "\n")
    }

    /// CSV 用の日付フォーマット
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    /// CSV エスケープ（カンマ・改行・ダブルクォートを含む場合）
    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
