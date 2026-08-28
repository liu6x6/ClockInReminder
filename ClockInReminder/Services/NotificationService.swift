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
        let calendar = Calendar.current
        let now = Date()
        
        for dateStr in scheduledDates {
            guard let date = formatter.date(from: dateStr) else { continue }
            
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            
            // 注册上班提醒（检查全局开关和当天是否禁用）
            if settings.isMorningEnabled(on: date) {
                // 检查通知触发时间是否已过去
                if let triggerDate = calendar.date(bySettingHour: settings.morningHour, minute: settings.morningMinute, second: 0, of: date),
                   triggerDate > now {
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
                        vibrate: settings.morningVibrate,
                        dateKey: dateStr
                    )
                }
            }
            
            // 注册下班提醒（检查全局开关和当天是否禁用）
            if settings.isEveningEnabled(on: date) {
                // 检查通知触发时间是否已过去
                if let triggerDate = calendar.date(bySettingHour: settings.eveningHour, minute: settings.eveningMinute, second: 0, of: date),
                   triggerDate > now {
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
                        vibrate: settings.eveningVibrate,
                        dateKey: dateStr
                    )
                }
            }
        }
        
        // 打印注册结果
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("✅ 已注册 \(requests.count) 个打卡提醒通知")
            for req in requests {
                if let trigger = req.trigger as? UNCalendarNotificationTrigger,
                   let nextDate = trigger.nextTriggerDate() {
                    let f = DateFormatter()
                    f.dateFormat = "MM-dd HH:mm"
                    print("  → \(req.content.title): \(f.string(from: nextDate))")
                }
            }
        }
    }
    
    // 注册单条通知
    private func scheduleNotification(
        id: String,
        dateComponents: DateComponents,
        title: String,
        message: String,
        soundName: String = "default",
        vibrate: Bool = true,
        dateKey: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        
        // 设置通知声音和震动
        if vibrate {
            // 启用震动：使用 critical sound 强制震动
            if soundName == "default" {
                content.sound = .defaultCritical
            } else {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
            }
        } else {
            // 不启用震动：使用普通声音
            if soundName == "default" {
                content.sound = .default
            } else {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
            }
        }
        
        // 添加日期标记到 userInfo
        content.userInfo = ["dateKey": dateKey]
        
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
    
    // 调度自定义提醒
    func scheduleCustomReminders(_ reminders: [CustomReminder]) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        let now = Date()
        
        for reminder in reminders {
            guard reminder.isEnabled else { continue }
            guard let date = formatter.date(from: reminder.date) else { continue }
            
            // 检查通知触发时间是否已过去
            if let triggerDate = calendar.date(bySettingHour: reminder.hour, minute: reminder.minute, second: 0, of: date),
               triggerDate > now {
                let components = calendar.dateComponents([.year, .month, .day], from: date)
                
                scheduleNotification(
                    id: "custom_\(reminder.id)",
                    dateComponents: DateComponents(
                        year: components.year,
                        month: components.month,
                        day: components.day,
                        hour: reminder.hour,
                        minute: reminder.minute
                    ),
                    title: reminder.title,
                    message: reminder.message,
                    soundName: reminder.sound,
                    vibrate: reminder.vibrate,
                    dateKey: reminder.date
                )
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
