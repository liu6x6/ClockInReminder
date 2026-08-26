import Foundation
import CoreLocation
import UserNotifications

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationService()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        authorizationStatus = LocationManager.shared.authorizationStatus
    }
    
    // 请求定位权限
    func requestPermission() {
        LocationManager.shared.requestPermission()
    }
    
    // 请求始终定位权限（地理围栏需要）
    func requestAlwaysPermission() {
        LocationManager.shared.requestAlwaysPermission()
    }
    
    // 开始地理围栏监听
    func startMonitoring(latitude: Double, longitude: Double, radius: Double, identifier: String) {
        // 先移除旧的围栏
        stopMonitoring(identifier: identifier)
        
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = CLCircularRegion(center: center, radius: radius, identifier: identifier)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        LocationManager.shared.startMonitoringGeofence(region: region)
        print("地理围栏已启动: \(identifier), 中心(\(latitude), \(longitude)), 半径\(radius)m")
    }
    
    // 停止地理围栏监听
    func stopMonitoring(identifier: String) {
        LocationManager.shared.stopMonitoringGeofence(identifier: identifier)
    }
    
    // 停止所有围栏
    func stopAllMonitoring() {
        LocationManager.shared.stopAllGeofenceMonitoring()
    }
    
    // 地理围栏通知
    private func sendGeofenceNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "geofence_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
