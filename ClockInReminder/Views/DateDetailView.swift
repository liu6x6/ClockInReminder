import SwiftUI
import SwiftData
import UserNotifications

struct DateDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allReminders: [CustomReminder]
    
    let currentDate: Date
    @Bindable var settings: ReminderSettings
    
    @State private var showAddReminder = false
    @State private var editingReminder: CustomReminder?
    
    private let calendar = Calendar.current
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: currentDate)
    }
    
    private var isPastDate: Bool {
        let today = calendar.startOfDay(for: Date())
        let targetDate = calendar.startOfDay(for: currentDate)
        return targetDate < today
    }
    
    // 获取当天的所有提醒
    private var dayReminders: [CustomReminder] {
        allReminders.filter { $0.date == dateString }
            .sorted { ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute) }
    }
    
    // 上班提醒（检查当天是否禁用）
    private var morningReminder: (time: String, enabled: Bool)? {
        guard settings.isMorningEnabled(on: currentDate) else { return nil }
        return (String(format: "%02d:%02d", settings.morningHour, settings.morningMinute), true)
    }
    
    // 下班提醒（检查当天是否禁用）
    private var eveningReminder: (time: String, enabled: Bool)? {
        guard settings.isEveningEnabled(on: currentDate) else { return nil }
        return (String(format: "%02d:%02d", settings.eveningHour, settings.eveningMinute), true)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if isPastDate {
                    // 过去的日期提示
                    VStack(spacing: 16) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.system(size: 60))
                            .foregroundStyle(.orange)
                        
                        Text("过去的日期")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("无法修改过去日期的提醒")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        // 固定提醒
                        Section {
                            if let morning = morningReminder {
                                HStack {
                                    Image(systemName: "sunrise.fill")
                                        .foregroundStyle(.orange)
                                    VStack(alignment: .leading) {
                                        Text("上班打卡")
                                            .font(.body)
                                        Text(morning.time)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button(role: .destructive) {
                                        disableMorningReminder()
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                            
                            if let evening = eveningReminder {
                                HStack {
                                    Image(systemName: "sunset.fill")
                                        .foregroundStyle(.blue)
                                    VStack(alignment: .leading) {
                                        Text("下班打卡")
                                            .font(.body)
                                        Text(evening.time)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button(role: .destructive) {
                                        disableEveningReminder()
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                            
                            // 如果当天没有固定提醒，显示恢复按钮
                            if morningReminder == nil || eveningReminder == nil {
                                Button {
                                    restoreAllReminders()
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.counterclockwise")
                                            .foregroundStyle(.blue)
                                        Text("恢复所有固定提醒")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        } header: {
                            Text("固定提醒")
                        } footer: {
                            Text("删除后仅影响当天，可在设置页面恢复全局开关")
                        }
                        
                        // 自定义提醒
                        if !dayReminders.isEmpty {
                            Section {
                                ForEach(dayReminders) { reminder in
                                    HStack {
                                        Image(systemName: "bell.fill")
                                            .foregroundStyle(.green)
                                        VStack(alignment: .leading) {
                                            Text(reminder.title)
                                                .font(.body)
                                            Text(reminder.timeString)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Toggle("", isOn: Binding(
                                            get: { reminder.isEnabled },
                                            set: { newValue in
                                                reminder.isEnabled = newValue
                                                scheduleAllReminders()
                                            }
                                        ))
                                        .labelsHidden()
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            deleteReminder(reminder)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                                    .onTapGesture {
                                        editingReminder = reminder
                                    }
                                }
                            } header: {
                                Text("自定义提醒")
                            }
                        }
                        
                        // 添加按钮
                        Section {
                            Button {
                                showAddReminder = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.blue)
                                    Text("添加自定义提醒")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(dateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAddReminder) {
                AddReminderView(date: dateString) { newReminder in
                    modelContext.insert(newReminder)
                    scheduleAllReminders()
                }
            }
            .sheet(item: $editingReminder) { reminder in
                EditReminderView(reminder: reminder) {
                    scheduleAllReminders()
                } onDelete: {
                    deleteReminder(reminder)
                }
            }
            .onAppear {
                scheduleAllReminders()
            }
        }
    }
    
    private var dateTitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: currentDate)
    }
    
    private func deleteReminder(_ reminder: CustomReminder) {
        // 删除通知
        let notificationId = "custom_\(reminder.id)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
        
        // 删除数据
        modelContext.delete(reminder)
    }
    
    private func disableMorningReminder() {
        settings.disableMorning(on: currentDate)
        // 删除已注册的通知
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["morning_\(dateString)"])
    }
    
    private func disableEveningReminder() {
        settings.disableEvening(on: currentDate)
        // 删除已注册的通知
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["evening_\(dateString)"])
    }
    
    private func restoreAllReminders() {
        settings.enableMorning(on: currentDate)
        settings.enableEvening(on: currentDate)
        scheduleAllReminders()
    }
    
    private func scheduleAllReminders() {
        NotificationService.shared.scheduleAll(settings: settings)
        NotificationService.shared.scheduleCustomReminders(dayReminders)
    }
}

struct AddReminderView: View {
    let date: String
    let onSave: (CustomReminder) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var hour = 12
    @State private var minute = 0
    @State private var message = ""
    @State private var sound = "default"
    @State private var vibrate = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("提醒标题", text: $title)
                    
                    HStack {
                        Text("时间")
                        Spacer()
                        Picker("时", selection: $hour) {
                            ForEach(0..<24, id: \.self) { h in
                                Text("\(h)时").tag(h)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 70, height: 60)
                        
                        Picker("分", selection: $minute) {
                            ForEach(0..<60, id: \.self) { m in
                                Text("\(m)分").tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 70, height: 60)
                    }
                    
                    TextField("通知内容（可选）", text: $message)
                } header: {
                    Text("基本信息")
                }
                
                Section {
                    Picker("通知声音", selection: $sound) {
                        Text("默认").tag("default")
                        Text("Glass").tag("Glass.aiff")
                        Text("Ping").tag("Ping.aiff")
                        Text("Pop").tag("Pop.aiff")
                    }
                    
                    Toggle("震动", isOn: $vibrate)
                } header: {
                    Text("通知设置")
                }
            }
            .navigationTitle("添加提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        let reminder = CustomReminder(
                            date: date,
                            title: title.isEmpty ? "自定义提醒" : title,
                            hour: hour,
                            minute: minute,
                            message: message,
                            sound: sound,
                            vibrate: vibrate
                        )
                        onSave(reminder)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

struct EditReminderView: View {
    @Bindable var reminder: CustomReminder
    let onSave: () -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("提醒标题", text: $reminder.title)
                    
                    HStack {
                        Text("时间")
                        Spacer()
                        Picker("时", selection: $reminder.hour) {
                            ForEach(0..<24, id: \.self) { h in
                                Text("\(h)时").tag(h)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 70, height: 60)
                        
                        Picker("分", selection: $reminder.minute) {
                            ForEach(0..<60, id: \.self) { m in
                                Text("\(m)分").tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 70, height: 60)
                    }
                    
                    TextField("通知内容", text: $reminder.message)
                } header: {
                    Text("基本信息")
                }
                
                Section {
                    Picker("通知声音", selection: $reminder.sound) {
                        Text("默认").tag("default")
                        Text("Glass").tag("Glass.aiff")
                        Text("Ping").tag("Ping.aiff")
                        Text("Pop").tag("Pop.aiff")
                    }
                    
                    Toggle("震动", isOn: $reminder.vibrate)
                } header: {
                    Text("通知设置")
                }
                
                Section {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("删除此提醒")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("编辑提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}
