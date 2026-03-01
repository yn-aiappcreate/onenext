import SwiftData
import Foundation

@Model
final class ReviewLog {
    @Attribute(.unique) var id: UUID
    var weekId: String
    var reviewedAt: Date
    var selectedGoalId: UUID?
    var note: String?

    init(weekId: String) {
        self.id = UUID()
        self.weekId = weekId
        self.reviewedAt = Date()
    }
}
