import SwiftUI
import SwiftData
import UserNotifications

@main
struct ClockInReminderApp: App {
    @State private var showLaunchScreen = true
    @State private var pendingConfirmation = false
    
    // 设置通知代理（前台也显示通知横幅）
    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if showLaunchScreen {
                    LaunchScreenView()
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation {
                                    showLaunchScreen = false
                                }
                            }
                        }
                } else {
                    ContentView(pendingConfirmation: $pendingConfirmation)
                        .onAppear {
                            // 请求通知权限
                            Task {
                                _ = await NotificationService.shared.requestPermission()
                            }
                        }
                }
            }
            .onOpenURL { _ in
                // App 进入前台时刷新通知
                NotificationRefreshHelper.refreshIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // 检查是否从通知进入
                checkNotificationLaunch()
            }
        }
        .modelContainer(for: ReminderSettings.self)
    }
    
    private func checkNotificationLaunch() {
        // 检查是否有待确认的通知
        if pendingConfirmation {
            confirmToday()
            pendingConfirmation = false
        }
    }
    
    private func confirmToday() {
        // 获取 SwiftData 容器
        let container = try? ModelContainer(for: ReminderSettings.self)
        guard let container = container else { return }
        
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ReminderSettings>()
        
        if let settings = try? context.fetch(descriptor).first {
            settings.confirmDate(Date())
            try? context.save()
        }
    }
}

// 通知刷新辅助
struct NotificationRefreshHelper {
    static func refreshIfNeeded() {
        // 检查待处理通知数量，如果少于 5 个则刷新
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            if requests.count < 5 {
                // 需要从 SwiftData 读取设置来刷新
                // 这里通过 NotificationCenter 通知 SettingsView 刷新
                NotificationCenter.default.post(name: .init("RefreshNotifications"), object: nil)
            }
        }
    }
}
