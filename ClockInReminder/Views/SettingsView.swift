import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var settings: ReminderSettings
    @State private var notificationGranted = false
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - 上班提醒
                Section {
                    Toggle("启用上班提醒", isOn: $settings.morningEnabled)
                    
                    if settings.morningEnabled {
                        HStack {
                            Text("提醒时间")
                            Spacer()
                            TimePicker(hour: $settings.morningHour, minute: $settings.morningMinute)
                        }
                        
                        HStack {
                            Text("通知内容")
                            Spacer()
                            TextField("打卡提醒", text: $settings.morningMessage)
                                .multilineTextAlignment(.trailing)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("上班打卡", systemImage: "sunrise.fill")
                }
                
                // MARK: - 上班通知声音
                Section {
                    Picker("通知声音", selection: $settings.morningSound) {
                        Text("默认").tag("default")
                        Text("Glass").tag("Glass.aiff")
                        Text("Ping").tag("Ping.aiff")
                        Text("Pop").tag("Pop.aiff")
                        Text("Purr").tag("Purr.aiff")
                        Text("Tink").tag("Tink.aiff")
                    }
                    
                    Toggle("震动", isOn: $settings.morningVibrate)
                } header: {
                    Label("上班提醒声音", systemImage: "speaker.wave.2.fill")
                } footer: {
                    if settings.morningVibrate {
                        Text("✅ 通知时会发出声音并震动")
                    } else {
                        Text("🔇 通知时仅发出声音，不震动")
                    }
                }
                
                // MARK: - 下班提醒
                Section {
                    Toggle("启用下班提醒", isOn: $settings.eveningEnabled)
                    
                    if settings.eveningEnabled {
                        HStack {
                            Text("提醒时间")
                            Spacer()
                            TimePicker(hour: $settings.eveningHour, minute: $settings.eveningMinute)
                        }
                        
                        HStack {
                            Text("通知内容")
                            Spacer()
                            TextField("下班打卡", text: $settings.eveningMessage)
                                .multilineTextAlignment(.trailing)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("下班打卡", systemImage: "sunset.fill")
                }
                
                // MARK: - 下班通知声音
                Section {
                    Picker("通知声音", selection: $settings.eveningSound) {
                        Text("默认").tag("default")
                        Text("Glass").tag("Glass.aiff")
                        Text("Ping").tag("Ping.aiff")
                        Text("Pop").tag("Pop.aiff")
                        Text("Purr").tag("Purr.aiff")
                        Text("Tink").tag("Tink.aiff")
                    }
                    
                    Toggle("震动", isOn: $settings.eveningVibrate)
                } header: {
                    Label("下班提醒声音", systemImage: "speaker.wave.2.fill")
                } footer: {
                    if settings.eveningVibrate {
                        Text("✅ 通知时会发出声音并震动")
                    } else {
                        Text("🔇 通知时仅发出声音，不震动")
                    }
                }
                
                // MARK: - 权限状态
                Section {
                    HStack {
                        Text("通知权限")
                        Spacer()
                        StatusBadge(granted: notificationGranted)
                    }
                    
                    Button("打开系统设置") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                } header: {
                    Label("权限状态", systemImage: "lock.shield.fill")
                }
            }
            .navigationTitle("设置")
            .onAppear {
                Task {
                    notificationGranted = await NotificationService.shared.checkPermission()
                }
                refreshNotifications()
            }
            .onChange(of: settings.morningEnabled) { _, _ in refreshNotifications() }
            .onChange(of: settings.morningHour) { _, _ in refreshNotifications() }
            .onChange(of: settings.morningMinute) { _, _ in refreshNotifications() }
            .onChange(of: settings.eveningEnabled) { _, _ in refreshNotifications() }
            .onChange(of: settings.eveningHour) { _, _ in refreshNotifications() }
            .onChange(of: settings.eveningMinute) { _, _ in refreshNotifications() }
            .onChange(of: settings.morningMessage) { _, _ in refreshNotifications() }
            .onChange(of: settings.eveningMessage) { _, _ in refreshNotifications() }
            .onChange(of: settings.morningSound) { _, _ in refreshNotifications() }
            .onChange(of: settings.eveningSound) { _, _ in refreshNotifications() }
            .onChange(of: settings.morningVibrate) { _, _ in refreshNotifications() }
            .onChange(of: settings.eveningVibrate) { _, _ in refreshNotifications() }
        }
    }
    
    private func refreshNotifications() {
        NotificationService.shared.scheduleAll(settings: settings, modelContext: modelContext)
    }
}

// MARK: - 时间选择器
struct TimePicker: View {
    @Binding var hour: Int
    @Binding var minute: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Picker("时", selection: $hour) {
                ForEach(0..<24, id: \.self) { h in
                    Text("\(h)时").tag(h)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 70, height: 40)
            
            Picker("分", selection: $minute) {
                ForEach(0..<60, id: \.self) { m in
                    Text("\(m)分").tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 70, height: 40)
        }
    }
}

// MARK: - 状态标签
struct StatusBadge: View {
    let granted: Bool
    
    var body: some View {
        Text(granted ? "已开启" : "未开启")
            .font(.footnote)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(granted ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
            .foregroundStyle(granted ? .green : .red)
            .clipShape(Capsule())
    }
}

#Preview {
    let settings = ReminderSettings()
    return SettingsView(settings: settings)
}
