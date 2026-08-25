import SwiftUI
import CoreLocation

struct AdvancedView: View {
    @Bindable var settings: ReminderSettings
    @State private var showLocationPicker = false
    @State private var showTestAlert = false
    
    private let locationService = LocationService.shared
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - 地理围栏
                Section {
                    Toggle("启用地理围栏提醒", isOn: $settings.geofenceEnabled)
                        .onChange(of: settings.geofenceEnabled) { _, newValue in
                            if newValue {
                                locationService.requestAlwaysPermission()
                            }
                            refreshGeofence()
                        }
                    
                    if settings.geofenceEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("公司名称")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            TextField("输入公司名称", text: $settings.companyName)
                        }
                        
                        Button {
                            showLocationPicker = true
                        } label: {
                            HStack {
                                Text("公司位置")
                                Spacer()
                                if settings.companyLatitude != 0 {
                                    Text("\(String(format: "%.4f", settings.companyLatitude)), \(String(format: "%.4f", settings.companyLongitude))")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("未设置")
                                        .foregroundStyle(.blue)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("围栏半径: \(Int(settings.geofenceRadius)) 米")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Slider(value: $settings.geofenceRadius, in: 10...200, step: 10)
                        }
                    }
                } header: {
                    Label("地理围栏", systemImage: "location.fill")
                } footer: {
                    Text("到达或离开公司附近时自动提醒，需要「始终允许」定位权限")
                }
                
                // MARK: - 测试
                Section {
                    Button {
                        testMorningNotification()
                    } label: {
                        Label("测试上班提醒", systemImage: "bell.fill")
                    }
                    
                    Button {
                        testEveningNotification()
                    } label: {
                        Label("测试下班提醒", systemImage: "bell.badge.fill")
                    }
                } header: {
                    Label("测试", systemImage: "wrench.fill")
                } footer: {
                    Text("发送测试通知，3 秒后弹出，请切到后台查看效果")
                }
                
                // MARK: - 权限状态
                Section {
                    HStack {
                        Text("定位权限")
                        Spacer()
                        LocationStatusBadge(status: locationService.authorizationStatus)
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
            .navigationTitle("高级")
            .onAppear {
                refreshGeofence()
            }
            .onChange(of: settings.companyLatitude) { _, _ in refreshGeofence() }
            .onChange(of: settings.companyLongitude) { _, _ in refreshGeofence() }
            .onChange(of: settings.geofenceRadius) { _, _ in refreshGeofence() }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView(settings: settings)
            }
            .alert("测试通知已发送", isPresented: $showTestAlert) {
                Button("好的", role: .cancel) {}
            } message: {
                Text("通知将在 3 秒后弹出，请切到后台查看效果")
            }
        }
    }
    
    private func refreshGeofence() {
        if settings.geofenceEnabled && settings.companyLatitude != 0 {
            locationService.startMonitoring(
                latitude: settings.companyLatitude,
                longitude: settings.companyLongitude,
                radius: settings.geofenceRadius,
                identifier: "company"
            )
        } else {
            locationService.stopAllMonitoring()
        }
    }
    
    private func testMorningNotification() {
        NotificationService.shared.sendTestNotification(
            title: "上班打卡提醒",
            message: settings.morningMessage
        )
        showTestAlert = true
    }
    
    private func testEveningNotification() {
        NotificationService.shared.sendTestNotification(
            title: "下班打卡提醒",
            message: settings.eveningMessage
        )
        showTestAlert = true
    }
}

// MARK: - 定位状态标签
struct LocationStatusBadge: View {
    let status: CLAuthorizationStatus
    
    var body: some View {
        Text(statusText)
            .font(.footnote)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.2))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }
    
    private var statusText: String {
        switch status {
        case .notDetermined: "未请求"
        case .restricted: "受限"
        case .denied: "已拒绝"
        case .authorizedAlways: "始终允许"
        case .authorizedWhenInUse: "使用时允许"
        @unknown default: "未知"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .authorizedAlways: .green
        case .authorizedWhenInUse: .orange
        case .denied: .red
        default: .gray
        }
    }
}

#Preview {
    let settings = ReminderSettings()
    return AdvancedView(settings: settings)
}
