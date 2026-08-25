import Foundation
import CoreLocation
import UserNotifications

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationService()
    
    private let locationManager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // 请求定位权限
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    // 请求始终定位权限（地理围栏需要）
    func requestAlwaysPermission() {
        locationManager.requestAlwaysAuthorization()
    }
    
    // 开始地理围栏监听
    func startMonitoring(latitude: Double, longitude: Double, radius: Double, identifier: String) {
        // 先移除旧的围栏
        stopMonitoring(identifier: identifier)
        
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = CLCircularRegion(center: center, radius: radius, identifier: identifier)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        locationManager.startMonitoring(for: region)
        print("地理围栏已启动: \(identifier), 中心(\(latitude), \(longitude)), 半径\(radius)m")
    }
    
    // 停止地理围栏监听
    func stopMonitoring(identifier: String) {
        let regions = locationManager.monitoredRegions.filter { $0.identifier == identifier }
        for region in regions {
            locationManager.stopMonitoring(for: region)
        }
    }
    
    // 停止所有围栏
    func stopAllMonitoring() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            currentLocation = location
        }
    }
    
    // 进入区域
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region.identifier == "company" {
            sendGeofenceNotification(
                title: "到达公司",
                message: "⏰ 到公司了！记得打卡"
            )
        }
    }
    
    // 离开区域
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if region.identifier == "company" {
            sendGeofenceNotification(
                title: "离开公司",
                message: "🏠 离开公司了！别忘了打卡"
            )
        }
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
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("地理围栏监听失败: \(error)")
    }
}
