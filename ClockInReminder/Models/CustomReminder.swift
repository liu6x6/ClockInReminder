import Foundation
import SwiftData

@Model
class CustomReminder {
    var id: String
    var date: String  // yyyy-MM-dd
    var title: String
    var hour: Int
    var minute: Int
    var message: String
    var sound: String
    var vibrate: Bool
    var isEnabled: Bool
    var createdAt: Date
    
    init(date: String, title: String, hour: Int, minute: Int, message: String = "", sound: String = "default", vibrate: Bool = true) {
        self.id = UUID().uuidString
        self.date = date
        self.title = title
        self.hour = hour
        self.minute = minute
        self.message = message.isEmpty ? title : message
        self.sound = sound
        self.vibrate = vibrate
        self.isEnabled = true
        self.createdAt = Date()
    }
    
    var timeString: String {
        return String(format: "%02d:%02d", hour, minute)
    }
}
