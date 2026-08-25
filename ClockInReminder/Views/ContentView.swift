import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsList: [ReminderSettings]
    @Binding var pendingConfirmation: Bool
    
    var body: some View {
        Group {
            if let settings = settingsList.first {
                TabView {
                    SettingsView(settings: settings)
                        .tabItem {
                            Label("设置", systemImage: "gearshape.fill")
                        }
                    
                    CalendarView(settings: settings)
                        .tabItem {
                            Label("日历", systemImage: "calendar")
                        }
                    
                    AdvancedView(settings: settings)
                        .tabItem {
                            Label("高级", systemImage: "location.fill")
                        }
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ConfirmTodayFromNotification"))) { notification in
                    // 用户点击通知，确认今天的打卡
                    confirmToday()
                }
            } else {
                ProgressView("初始化中...")
                    .onAppear {
                        let defaultSettings = ReminderSettings()
                        modelContext.insert(defaultSettings)
                    }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // 检查是否从通知进入
                if pendingConfirmation {
                    confirmToday()
                    pendingConfirmation = false
                }
                
                if let settings = settingsList.first {
                    NotificationService.shared.scheduleAll(settings: settings)
                }
            }
        }
    }
    
    private func confirmToday() {
        if let settings = settingsList.first {
            settings.confirmDate(Date())
        }
    }
}

#Preview {
    ContentView(pendingConfirmation: .constant(false))
        .modelContainer(for: ReminderSettings.self, inMemory: true)
}
