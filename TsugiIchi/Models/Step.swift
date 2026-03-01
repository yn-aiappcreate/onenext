import SwiftData
import Foundation

@Model
final class Step {
    @Attribute(.unique) var id: UUID
    var title: String
    var durationMin: Int
    var dueDate: Date?
    var type: StepType
    var status: StepStatus
    var sortOrder: Int
    var scheduledAt: Date?

    var goal: Goal?

    init(
        title: String,
        durationMin: Int = 30,
        type: StepType = .auto,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.durationMin = durationMin
        self.type = type
        self.status = .pending
        self.sortOrder = sortOrder
    }
}

// MARK: - Enums

enum StepType: String, Codable {
    case auto
    case manual
}

enum StepStatus: String, Codable {
    case pending
    case scheduled
    case done
    case postponed
    case discarded
}
