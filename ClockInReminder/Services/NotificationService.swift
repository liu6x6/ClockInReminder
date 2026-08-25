import Foundation
import UserNotifications
import UIKit

class NotificationService {
    static let shared = NotificationService()
    
    // 请求通知权限
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("通知权限请求失败: \(error)")
            return false
        }
    }
    
    // 检查权限状态
    func checkPermission() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    // 清除所有已注册的通知
    func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // 注册所有提醒通知（基于日历选择的日期）
    func scheduleAll(settings: ReminderSettings) {
        removeAllPendingNotifications()
        
        // 获取所有已安排的日期
        let scheduledDates = settings.scheduledDates
        
        guard !scheduledDates.isEmpty else {
            print("没有安排打卡日期，跳过通知注册")
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        for dateStr in scheduledDates {
            guard let date = formatter.date(from: dateStr) else { continue }
            
            // 只注册未来的日期
            if date < Date() {
                continue
            }
            
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            
            // 注册上班提醒
            if settings.morningEnabled {
                scheduleNotification(
                    id: "morning_\(dateStr)",
                    dateComponents: DateComponents(
                        year: components.year,
                        month: components.month,
                        day: components.day,
                        hour: settings.morningHour,
                        minute: settings.morningMinute
                    ),
                    title: "上班打卡提醒",
                    message: settings.morningMessage,
                    soundName: settings.morningSound,
                    dateKey: dateStr
                )
            }
            
            // 注册下班提醒
            if settings.eveningEnabled {
                scheduleNotification(
                    id: "evening_\(dateStr)",
                    dateComponents: DateComponents(
                        year: components.year,
                        month: components.month,
                        day: components.day,
                        hour: settings.eveningHour,
                        minute: settings.eveningMinute
                    ),
                    title: "下班打卡提醒",
                    message: settings.eveningMessage,
                    soundName: settings.eveningSound,
                    dateKey: dateStr
                )
            }
        }
        
        print("已注册 \(scheduledDates.count) 天的打卡提醒")
    }
    
    // 注册单条通知
    private func scheduleNotification(
        id: String,
        dateComponents: DateComponents,
        title: String,
        message: String,
        soundName: String = "default",
        dateKey: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        
        // 添加日期标记到 userInfo
        content.userInfo = ["dateKey": dateKey]
        
        // 设置通知声音
        if soundName == "default" {
            content.sound = .default
        } else {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("通知注册失败 [\(id)]: \(error)")
            }
        }
    }
    
    // 发送即时测试通知
    func sendTestNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        content.userInfo = ["dateKey": ReminderSettings.dateKey(Date())]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: "test_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("测试通知发送失败: \(error)")
            }
        }
    }
}

// 前台也显示通知横幅
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    // 前台显示通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    // 用户点击通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // 发送通知，告诉 App 需要确认今天的打卡
        NotificationCenter.default.post(
            name: Notification.Name("ConfirmTodayFromNotification"),
            object: nil,
            userInfo: userInfo
        )
        
        completionHandler()
    }
}
