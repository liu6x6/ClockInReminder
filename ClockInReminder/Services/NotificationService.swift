import Foundation
import SwiftData
import UserNotifications
import UIKit

class NotificationService {
    static let shared = NotificationService()
    private let maximumPendingNotificationCount = 64

    private struct FixedReminder {
        let date: Date
        let id: String
        let title: String
        let message: String
        let soundName: String
        let vibrate: Bool
        let dateKey: String
    }
    
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
    
    // 注册所有提醒通知（基于日历选择的日期）
    func scheduleAll(settings: ReminderSettings, modelContext: ModelContext) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                let fixedReminderRequests = requests.filter {
                    $0.identifier.hasPrefix("morning_") || $0.identifier.hasPrefix("evening_")
                }
                let otherReminderCount = requests.count - fixedReminderRequests.count
                let reminders = self.fixedReminders(settings: settings)
                let scheduledReminders = Array(
                    reminders.prefix(max(0, self.maximumPendingNotificationCount - otherReminderCount))
                )

                center.removePendingNotificationRequests(
                    withIdentifiers: fixedReminderRequests.map(\.identifier)
                )
                self.addFixedReminders(scheduledReminders) {
                    center.getPendingNotificationRequests { updatedRequests in
                        let scheduledIdentifiers = Set(
                            updatedRequests
                                .filter { $0.identifier.hasPrefix("morning_") || $0.identifier.hasPrefix("evening_") }
                                .map(\.identifier)
                        )

                        DispatchQueue.main.async {
                            self.syncScheduleRecords(
                                reminders: reminders,
                                scheduledIdentifiers: scheduledIdentifiers,
                                modelContext: modelContext
                            )
                        }
                    }
                }

                if reminders.count > scheduledReminders.count {
                    print("待处理通知最多只能保留 \(self.maximumPendingNotificationCount) 条；已优先注册最近 \(scheduledReminders.count) 条固定打卡提醒。")
                }
            }
        }
    }

    private func fixedReminders(settings: ReminderSettings) -> [FixedReminder] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"

        let calendar = Calendar.current
        let now = Date()
        var reminders: [FixedReminder] = []

        for dateKey in settings.scheduledDates {
            guard let date = formatter.date(from: dateKey) else { continue }

            if settings.isMorningEnabled(on: date),
               let triggerDate = calendar.date(bySettingHour: settings.morningHour, minute: settings.morningMinute, second: 0, of: date),
               triggerDate > now {
                reminders.append(FixedReminder(
                    date: triggerDate,
                    id: "morning_\(dateKey)",
                    title: "上班打卡提醒",
                    message: settings.morningMessage,
                    soundName: settings.morningSound,
                    vibrate: settings.morningVibrate,
                    dateKey: dateKey
                ))
            }

            if settings.isEveningEnabled(on: date),
               let triggerDate = calendar.date(bySettingHour: settings.eveningHour, minute: settings.eveningMinute, second: 0, of: date),
               triggerDate > now {
                reminders.append(FixedReminder(
                    date: triggerDate,
                    id: "evening_\(dateKey)",
                    title: "下班打卡提醒",
                    message: settings.eveningMessage,
                    soundName: settings.eveningSound,
                    vibrate: settings.eveningVibrate,
                    dateKey: dateKey
                ))
            }
        }

        return reminders.sorted { $0.date < $1.date }
    }

    private func addFixedReminders(_ reminders: [FixedReminder], completion: @escaping () -> Void) {
        let calendar = Calendar.current
        let group = DispatchGroup()

        for reminder in reminders {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
            group.enter()
            scheduleNotification(
                id: reminder.id,
                dateComponents: components,
                title: reminder.title,
                message: reminder.message,
                soundName: reminder.soundName,
                vibrate: reminder.vibrate,
                dateKey: reminder.dateKey,
                completion: { _ in
                    group.leave()
                }
            )
        }

        group.notify(queue: .main) {
            completion()
        }
    }

    private func syncScheduleRecords(
        reminders: [FixedReminder],
        scheduledIdentifiers: Set<String>,
        modelContext: ModelContext
    ) {
        do {
            let existingRecords = try modelContext.fetch(FetchDescriptor<NotificationScheduleRecord>())
            var recordsByIdentifier = Dictionary(
                uniqueKeysWithValues: existingRecords.map { ($0.identifier, $0) }
            )
            let reminderIdentifiers = Set(reminders.map(\.id))

            for record in existingRecords where !reminderIdentifiers.contains(record.identifier) {
                modelContext.delete(record)
                recordsByIdentifier[record.identifier] = nil
            }

            for reminder in reminders {
                let isSystemScheduled = scheduledIdentifiers.contains(reminder.id)
                if let record = recordsByIdentifier[reminder.id] {
                    record.dateKey = reminder.dateKey
                    record.isSystemScheduled = isSystemScheduled
                    record.updatedAt = Date()
                } else {
                    modelContext.insert(
                        NotificationScheduleRecord(
                            identifier: reminder.id,
                            dateKey: reminder.dateKey,
                            isSystemScheduled: isSystemScheduled
                        )
                    )
                }
            }

            try modelContext.save()
        } catch {
            print("通知状态保存失败: \(error)")
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
        dateKey: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        
        // Critical Alert 需要 Apple 审核授予的专用 entitlement。普通打卡提醒使用标准通知声音。
        if soundName == "default" {
            content.sound = .default
        } else {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
        }
        
        // 添加日期标记到 userInfo
        content.userInfo = ["dateKey": dateKey]
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("通知注册失败 [\(id)]: \(error)")
            }
            completion?(error)
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
