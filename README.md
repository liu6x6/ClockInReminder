# ClockInReminder - 打卡提醒 App

一个 iOS App，在工作日自动提醒用户打卡，支持定时通知 + 地理围栏双重触发。

## 功能特性

- ⏰ **上班打卡提醒**：工作日早上定时弹出通知
- 🏠 **下班打卡提醒**：工作日晚上定时弹出通知
- 📍 **地理围栏提醒**：到达/离开公司附近时自动提醒
- ⚙️ **自定义设置**：时间、地点、通知内容均可自定义
- 🔔 **通知 + 声音**：本地通知，带声音提醒
- 📱 **后台自动触发**：App 关闭也能正常提醒

## 系统要求

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## 使用方法

### 1. 打开项目

```bash
open ClockInReminder.xcodeproj
```

### 2. 配置签名

在 Xcode 中选择项目 → Signing & Capabilities → 选择你的 Team

### 3. 运行到设备

⚠️ 注意：通知和定位功能需要在真机上测试，模拟器无法完全测试

### 4. 首次使用

1. 首次启动会请求通知权限 → 允许
2. 设置上班/下班提醒时间
3. 开启地理围栏 → 请求定位权限 → 选择「始终允许」
4. 在地图上选择公司位置
5. 点击「测试」按钮验证效果

## 项目结构

```
ClockInReminder/
├── ClockInReminderApp.swift      # App 入口
├── Models/
│   └── ReminderSettings.swift    # 数据模型（SwiftData）
├── Views/
│   ├── ContentView.swift         # 主界面
│   ├── SettingsView.swift        # 设置页面
│   └── LocationPickerView.swift  # 地图选点
├── Services/
│   ├── NotificationService.swift # 通知服务
│   └── LocationService.swift     # 地理围栏服务
└── Info.plist                    # 权限配置
```

## 技术实现

### 定时通知
- 使用 `UNCalendarNotificationTrigger` 注册定时通知
- 系统级调度，App 关闭也能触发
- 每次设置变更自动刷新未来 7 天的通知

### 地理围栏
- 使用 `CLLocationManager.startMonitoring(for:)` 监听区域
- 系统级监听，低功耗（基站+Wi-Fi）
- 进入/离开区域自动触发通知

### 数据持久化
- 使用 SwiftData 存储用户设置
- 设置变更自动保存到本地

## 权限说明

| 权限 | 用途 |
|------|------|
| 通知权限 | 弹出打卡提醒通知 |
| 定位权限（始终） | 监听到达/离开公司 |

## 注意事项

1. 地理围栏需要「始终允许」定位权限
2. 定时通知最多预注册 64 个，每次打开 App 自动刷新
3. 地理围栏最多同时监听 20 个区域
4. 建议在真机上测试完整功能

## License

MIT
