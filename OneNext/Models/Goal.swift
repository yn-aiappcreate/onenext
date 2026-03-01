import SwiftData
import Foundation

@Model
final class Goal {
    @Attribute(.unique) var id: UUID
    var title: String
    var category: GoalCategory?
    var priority: GoalPriority
    var dueDate: Date?
    var note: String?
    @Attribute(.externalStorage) var imageData: Data?
    var status: GoalStatus
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Step.goal)
    var steps: [Step] = []

    init(
        title: String,
        category: GoalCategory? = nil,
        priority: GoalPriority = .medium,
        dueDate: Date? = nil,
        note: String? = nil,
        imageData: Data? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.category = category
        self.priority = priority
        self.dueDate = dueDate
        self.note = note
        self.imageData = imageData
        self.status = .active
        self.createdAt = Date()
    }
}

// MARK: - Enums

enum GoalCategory: String, Codable, CaseIterable, Identifiable {
    case travel   = "旅行"
    case event    = "イベント"
    case learning = "学習"
    case health   = "健康"
    case hobby    = "趣味"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .travel:   "airplane"
        case .event:    "party.popper"
        case .learning: "book"
        case .health:   "heart"
        case .hobby:    "paintpalette"
        }
    }
}

enum GoalPriority: Int, Codable, CaseIterable, Comparable, Identifiable {
    case low = 0
    case medium = 1
    case high = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .low:    "低"
        case .medium: "中"
        case .high:   "高"
        }
    }

    static func < (lhs: GoalPriority, rhs: GoalPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum GoalStatus: String, Codable {
    case active
    case completed
    case archived
}
