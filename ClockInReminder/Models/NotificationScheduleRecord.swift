import Foundation
import SwiftData

@Model
class NotificationScheduleRecord {
    var identifier: String
    var dateKey: String
    var isSystemScheduled: Bool
    var updatedAt: Date

    init(identifier: String, dateKey: String, isSystemScheduled: Bool) {
        self.identifier = identifier
        self.dateKey = dateKey
        self.isSystemScheduled = isSystemScheduled
        self.updatedAt = Date()
    }
}
