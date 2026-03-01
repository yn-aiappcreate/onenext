import SwiftData
import Foundation

@Model
final class PlanSlot {
    @Attribute(.unique) var id: UUID
    var weekId: String
    var index: Int
    var startAt: Date?
    var endAt: Date?

    @Relationship var step: Step?

    init(weekId: String, index: Int, step: Step? = nil) {
        self.id = UUID()
        self.weekId = weekId
        self.index = index
        self.step = step
    }
}
