import SwiftUI
import MapKit
import CoreLocation

// MARK: - 定位管理器（单例）
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestAlwaysPermission() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func startUpdating() {
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdating() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - 地理围栏
    
    func startMonitoringGeofence(region: CLCircularRegion) {
        locationManager.startMonitoring(for: region)
    }
    
    func stopMonitoringGeofence(identifier: String) {
        let regions = locationManager.monitoredRegions.filter { $0.identifier == identifier }
        for region in regions {
            locationManager.stopMonitoring(for: region)
        }
    }
    
    func stopAllGeofenceMonitoring() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            currentLocation = location
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("定位失败: \(error)")
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
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("地理围栏监听失败: \(error)")
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

struct LocationPickerView: View {
    @Bindable var settings: ReminderSettings
    @Environment(\.dismiss) private var dismiss
    
    @State private var cameraPosition: MapCameraPosition
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    
    // 手动输入经纬度
    @State private var showManualInput = false
    @State private var manualLatitude = ""
    @State private var manualLongitude = ""
    
    @StateObject private var locationManager = LocationManager.shared
    
    init(settings: ReminderSettings) {
        self.settings = settings
        
        if settings.companyLatitude != 0 {
            let coordinate = CLLocationCoordinate2D(
                latitude: settings.companyLatitude,
                longitude: settings.companyLongitude
            )
            _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )))
            _selectedCoordinate = State(initialValue: coordinate)
            _manualLatitude = State(initialValue: String(format: "%.6f", settings.companyLatitude))
            _manualLongitude = State(initialValue: String(format: "%.6f", settings.companyLongitude))
        } else {
            _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )))
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索公司地址", text: $searchText)
                        .onSubmit { searchLocation() }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(.bar)
                
                // 搜索结果
                if !searchResults.isEmpty {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(searchResults, id: \.self) { item in
                                Button {
                                    selectSearchResult(item)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name ?? "未知地点")
                                                .font(.body)
                                                .foregroundStyle(.primary)
                                            if let address = item.placemark.title {
                                                Text(address)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                }
                                Divider()
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                    .background(.bar)
                }
                
                // 可拖动标记的地图
                DraggableMapView(
                    selectedCoordinate: $selectedCoordinate,
                    cameraPosition: $cameraPosition,
                    fenceRadius: settings.geofenceRadius
                )
                
                // 底部信息栏
                VStack(spacing: 10) {
                    if let coord = selectedCoordinate {
                        Text("📍 \(String(format: "%.6f", coord.latitude)), \(String(format: "%.6f", coord.longitude))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("拖动地图上的标记来选择位置")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 10) {
                        // 定位到当前位置
                        Button {
                            moveToCurrentLocation()
                        } label: {
                            Label("定位", systemImage: "location.fill")
                        }
                        .buttonStyle(.bordered)
                        
                        // 手动输入
                        Button {
                            showManualInput.toggle()
                        } label: {
                            Label("输入", systemImage: "keyboard")
                        }
                        .buttonStyle(.bordered)
                        
                        // 保存
                        Button("保存") {
                            saveAndDismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedCoordinate == nil)
                    }
                }
                .padding()
                .background(.bar)
            }
            .navigationTitle("选择公司位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .sheet(isPresented: $showManualInput) {
                manualInputSheet
            }
            .onAppear {
                requestLocation()
            }
        }
    }
    
    // 手动输入面板
    private var manualInputSheet: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("纬度")
                        TextField("如: 31.2304", text: $manualLatitude)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("经度")
                        TextField("如: 121.4737", text: $manualLongitude)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Label("输入经纬度", systemImage: "location.fill")
                } footer: {
                    Text("纬度: -90 ~ 90，经度: -180 ~ 180")
                }
                
                Section {
                    Button("应用到地图") {
                        applyManualCoordinates()
                    }
                    .disabled(!isValidCoordinates())
                }
            }
            .navigationTitle("手动输入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showManualInput = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func isValidCoordinates() -> Bool {
        guard let lat = Double(manualLatitude),
              let lon = Double(manualLongitude) else { return false }
        return lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
    }
    
    private func applyManualCoordinates() {
        guard let lat = Double(manualLatitude),
              let lon = Double(manualLongitude),
              isValidCoordinates() else { return }
        
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        selectedCoordinate = coordinate
        
        // 移动地图到新位置
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
        
        showManualInput = false
    }
    
    private func requestLocation() {
        locationManager.requestPermission()
        locationManager.startUpdating()
        
        // 如果没有已保存的位置，尝试定位到当前位置
        if selectedCoordinate == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if let location = locationManager.currentLocation {
                    selectedCoordinate = location.coordinate
                    withAnimation {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))
                    }
                }
            }
        }
    }
    
    private func moveToCurrentLocation() {
        // 确保正在获取位置
        locationManager.startUpdating()
        
        // 等待获取位置后移动地图
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let location = locationManager.currentLocation {
                selectedCoordinate = location.coordinate
                withAnimation {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
            }
        }
    }
    
    private func searchLocation() {
        guard !searchText.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        
        if let current = locationManager.currentLocation {
            request.region = MKCoordinateRegion(
                center: current.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
            )
        }
        
        MKLocalSearch(request: request).start { response, error in
            if let items = response?.mapItems {
                searchResults = items
            }
        }
    }
    
    private func selectSearchResult(_ item: MKMapItem) {
        selectedCoordinate = item.placemark.coordinate
        if let name = item.name, !name.isEmpty {
            settings.companyName = name
        }
        manualLatitude = String(format: "%.6f", item.placemark.coordinate.latitude)
        manualLongitude = String(format: "%.6f", item.placemark.coordinate.longitude)
        
        // 移动地图到搜索结果
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: item.placemark.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
        
        searchResults = []
        searchText = ""
    }
    
    private func saveAndDismiss() {
        guard let coord = selectedCoordinate else { return }
        settings.companyLatitude = coord.latitude
        settings.companyLongitude = coord.longitude
        dismiss()
    }
}

// MARK: - 可拖动标记的地图视图
struct DraggableMapView: UIViewRepresentable {
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var cameraPosition: MapCameraPosition
    let fenceRadius: Double
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        
        // 如果有已保存的坐标，显示标记
        if let coord = selectedCoordinate {
            context.coordinator.addAnnotation(at: coord, on: mapView)
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新围栏圆圈
        context.coordinator.updateFenceRadius(mapView, radius: fenceRadius)
        
        // 如果外部更新了坐标，同步到地图
        if let coord = selectedCoordinate {
            if let annotation = mapView.annotations.first(where: { $0 is MKPointAnnotation }) as? MKPointAnnotation {
                if annotation.coordinate.latitude != coord.latitude || annotation.coordinate.longitude != coord.longitude {
                    annotation.coordinate = coord
                    context.coordinator.updateFenceRadius(mapView, radius: fenceRadius)
                    
                    // 移动地图到新位置
                    let region = MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                    mapView.setRegion(region, animated: true)
                }
            } else {
                context.coordinator.addAnnotation(at: coord, on: mapView)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        let parent: DraggableMapView
        private var fenceOverlay: MKCircle?
        
        init(_ parent: DraggableMapView) {
            self.parent = parent
        }
        
        func addAnnotation(at coordinate: CLLocationCoordinate2D, on mapView: MKMapView) {
            // 清除旧标记
            mapView.removeAnnotations(mapView.annotations.filter { $0 is MKPointAnnotation })
            
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = "公司位置"
            mapView.addAnnotation(annotation)
            
            updateFenceRadius(mapView, radius: parent.fenceRadius)
        }
        
        func updateFenceRadius(_ mapView: MKMapView, radius: Double) {
            // 移除旧圆圈
            if let old = fenceOverlay {
                mapView.removeOverlay(old)
            }
            
            // 添加新圆圈
            if let annotation = mapView.annotations.first(where: { $0 is MKPointAnnotation }) {
                let circle = MKCircle(center: annotation.coordinate, radius: radius)
                mapView.addOverlay(circle)
                fenceOverlay = circle
            }
        }
        
        // MARK: - MKMapViewDelegate
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is MKPointAnnotation else { return nil }
            
            let identifier = "draggablePin"
            var view: MKMarkerAnnotationView
            
            if let dequeued = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
                view = dequeued
            } else {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            }
            
            view.markerTintColor = .red
            view.isDraggable = true
            view.canShowCallout = true
            
            return view
        }
        
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
            switch newState {
            case .ending:
                if let annotation = view.annotation {
                    parent.selectedCoordinate = annotation.coordinate
                    updateFenceRadius(mapView, radius: parent.fenceRadius)
                }
                view.setDragState(.none, animated: true)
                
            case .canceling:
                view.setDragState(.none, animated: true)
                
            default:
                break
            }
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = UIColor.blue.withAlphaComponent(0.1)
                renderer.strokeColor = UIColor.blue.withAlphaComponent(0.5)
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

#Preview {
    let settings = ReminderSettings()
    return LocationPickerView(settings: settings)
}
