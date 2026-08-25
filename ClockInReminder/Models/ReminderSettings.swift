import SwiftUI
import SwiftData

@Model
class ReminderSettings {
    // 上班提醒
    var morningEnabled: Bool
    var morningHour: Int
    var morningMinute: Int
    
    // 下班提醒
    var eveningEnabled: Bool
    var eveningHour: Int
    var eveningMinute: Int
    
    // 地理围栏
    var geofenceEnabled: Bool
    var companyName: String
    var companyLatitude: Double
    var companyLongitude: Double
    var geofenceRadius: Double  // 米
    
    // 通知内容
    var morningMessage: String
    var eveningMessage: String
    
    // 通知声音
    var morningSound: String
    var eveningSound: String
    
    // 打卡日期（格式: "yyyy-MM-dd"）
    var scheduledDates: [String]
    
    // 已确认收到通知的日期（格式: "yyyy-MM-dd"）
    var confirmedDates: [String]
    
    init() {
        self.morningEnabled = true
        self.morningHour = 9
        self.morningMinute = 20
        
        self.eveningEnabled = true
        self.eveningHour = 18
        self.eveningMinute = 5
        
        self.geofenceEnabled = false
        self.companyName = "公司"
        self.companyLatitude = 0
        self.companyLongitude = 0
        self.geofenceRadius = 100
        
        self.morningMessage = "⏰ 记得打卡！别忘了打开打卡 App"
        self.eveningMessage = "🏠 下班了！别忘了打卡"
        
        self.morningSound = "default"
        self.eveningSound = "default"
        
        self.scheduledDates = []
        self.confirmedDates = []
    }
    
    // 检查某个日期是否已安排打卡
    func isScheduled(_ date: Date) -> Bool {
        let key = Self.dateKey(date)
        return scheduledDates.contains(key)
    }
    
    // 切换某个日期的打卡状态
    func toggleDate(_ date: Date) {
        let key = Self.dateKey(date)
        if scheduledDates.contains(key) {
            scheduledDates.removeAll { $0 == key }
        } else {
            scheduledDates.append(key)
        }
    }
    
    // 检查某个日期是否已确认
    func isConfirmed(_ date: Date) -> Bool {
        let key = Self.dateKey(date)
        return confirmedDates.contains(key)
    }
    
    // 确认某个日期已收到通知
    func confirmDate(_ date: Date) {
        let key = Self.dateKey(date)
        if !confirmedDates.contains(key) {
            confirmedDates.append(key)
        }
    }
    
    // 取消确认
    func unconfirmDate(_ date: Date) {
        let key = Self.dateKey(date)
        confirmedDates.removeAll { $0 == key }
    }
    
    // 获取日期字符串 key
    static func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // 获取某个月已安排的日期数量
    func scheduledCount(in month: Date) -> Int {
        return countDates(in: month, from: scheduledDates)
    }
    
    // 获取某个月已确认的日期数量
    func completedCount(in month: Date) -> Int {
        return countDates(in: month, from: confirmedDates)
    }
    
    private func countDates(in month: Date, from dates: [String]) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: month)
        guard let monthStart = calendar.date(from: components) else { return 0 }
        
        let range = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<1
        var count = 0
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                let key = Self.dateKey(date)
                if dates.contains(key) {
                    count += 1
                }
            }
        }
        return count
    }
}
