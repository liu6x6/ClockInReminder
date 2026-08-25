import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerView: View {
    @Bindable var settings: ReminderSettings
    @Environment(\.dismiss) private var dismiss
    
    @State private var cameraPosition: MapCameraPosition
    @State private var mapCenterCoordinate: CLLocationCoordinate2D?
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedLocation: CLLocationCoordinate2D?
    
    // 手动输入经纬度
    @State private var showManualInput = false
    @State private var manualLatitude = ""
    @State private var manualLongitude = ""
    
    // 定位管理器
    @State private var locationManager = CLLocationManager()
    @State private var currentLocation: CLLocation?
    
    // 标记拖动
    @State private var isDraggingMarker = false
    
    init(settings: ReminderSettings) {
        self.settings = settings
        
        // 如果已设置过位置，定位到该位置
        if settings.companyLatitude != 0 {
            let coordinate = CLLocationCoordinate2D(
                latitude: settings.companyLatitude,
                longitude: settings.companyLongitude
            )
            _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )))
            _selectedLocation = State(initialValue: coordinate)
            _manualLatitude = State(initialValue: String(format: "%.6f", settings.companyLatitude))
            _manualLongitude = State(initialValue: String(format: "%.6f", settings.companyLongitude))
        } else {
            // 默认显示上海（会在 onAppear 中获取当前位置）
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
                    TextField("搜索公司地址（如：公司名、地址）", text: $searchText)
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
                
                // 搜索结果列表
                if !searchResults.isEmpty {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(searchResults, id: \.self) { item in
                                Button {
                                    selectSearchResult(item)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.name ?? "未知地点")
                                                .font(.body)
                                                .foregroundStyle(.primary)
                                            if let address = item.placemark.title {
                                                Text(address)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                }
                                Divider()
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                    .background(.bar)
                }
                
                // 地图（可拖动标记）
                ZStack(alignment: .center) {
                    Map(position: $cameraPosition) {
                        // 显示已选位置
                        if let selected = selectedLocation {
                            Annotation(settings.companyName, coordinate: selected) {
                                // 自定义可拖动标记
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.red)
                                    .background(Circle().fill(.white).frame(width: 16, height: 16))
                                    .shadow(radius: 3)
                                    .offset(y: -16)
                            }
                            
                            // 围栏范围
                            MapCircle(center: selected, radius: settings.geofenceRadius)
                                .foregroundStyle(.blue.opacity(0.1))
                                .stroke(.blue.opacity(0.5), lineWidth: 2)
                        }
                        
                        // 显示用户位置
                        UserAnnotation()
                    }
                    .onMapCameraChange(frequency: .continuous) { context in
                        mapCenterCoordinate = context.region.center
                    }
                    
                    // 中心十字准星（当没有选择位置时显示）
                    if selectedLocation == nil {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.blue)
                            .padding(12)
                            .background(Circle().fill(.white))
                            .shadow(radius: 2)
                    }
                }
                
                // 底部操作栏
                VStack(spacing: 12) {
                    // 位置信息
                    if let selected = selectedLocation {
                        Text("已选择: \(String(format: "%.6f", selected.latitude)), \(String(format: "%.6f", selected.longitude))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if let center = mapCenterCoordinate {
                        Text("移动地图选择位置: \(String(format: "%.6f", center.latitude)), \(String(format: "%.6f", center.longitude))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("移动地图选择位置")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        // 定位到当前位置
                        Button {
                            moveToCurrentLocation()
                        } label: {
                            Image(systemName: "location.fill")
                        }
                        .buttonStyle(.bordered)
                        
                        // 手动输入经纬度
                        Button {
                            showManualInput.toggle()
                        } label: {
                            Image(systemName: "keyboard")
                        }
                        .buttonStyle(.bordered)
                        
                        // 使用地图中心（确认当前位置）
                        Button("确认位置") {
                            confirmMapCenter()
                        }
                        .buttonStyle(.borderedProminent)
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
                requestLocationPermission()
            }
        }
    }
    
    // 手动输入经纬度面板
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
                    Text("纬度范围: -90 ~ 90，经度范围: -180 ~ 180")
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
                    Button("完成") {
                        showManualInput = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // 检查坐标是否有效
    private func isValidCoordinates() -> Bool {
        guard let lat = Double(manualLatitude),
              let lon = Double(manualLongitude) else {
            return false
        }
        return lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
    }
    
    // 应用手动输入的坐标
    private func applyManualCoordinates() {
        guard let lat = Double(manualLatitude),
              let lon = Double(manualLongitude),
              isValidCoordinates() else {
            return
        }
        
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        selectedLocation = coordinate
        
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
        
        showManualInput = false
    }
    
    // 请求定位权限
    private func requestLocationPermission() {
        locationManager.delegate = LocationManagerDelegate.shared
        locationManager.requestWhenInUseAuthorization()
        
        // 延迟获取位置
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let location = LocationManagerDelegate.shared.currentLocation {
                currentLocation = location
                if settings.companyLatitude == 0 && selectedLocation == nil {
                    moveToCurrentLocation()
                }
            } else {
                // 开始更新位置
                locationManager.startUpdatingLocation()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if let location = LocationManagerDelegate.shared.currentLocation {
                        currentLocation = location
                        if settings.companyLatitude == 0 && selectedLocation == nil {
                            moveToCurrentLocation()
                        }
                    }
                }
            }
        }
    }
    
    // 移动到当前位置
    private func moveToCurrentLocation() {
        if let location = LocationManagerDelegate.shared.currentLocation ?? currentLocation {
            let coordinate = location.coordinate
            withAnimation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
            mapCenterCoordinate = coordinate
        } else {
            // 重新请求位置
            locationManager.startUpdatingLocation()
        }
    }
    
    // 搜索地址
    private func searchLocation() {
        guard !searchText.isEmpty else { return }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        
        // 如果有当前位置，优先搜索附近
        if let current = LocationManagerDelegate.shared.currentLocation {
            request.region = MKCoordinateRegion(
                center: current.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
            )
        }
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let items = response?.mapItems {
                searchResults = items
            }
        }
    }
    
    // 选择搜索结果
    private func selectSearchResult(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        selectedLocation = coordinate
        
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
        
        if let name = item.name, !name.isEmpty {
            settings.companyName = name
        }
        
        // 更新手动输入框
        manualLatitude = String(format: "%.6f", coordinate.latitude)
        manualLongitude = String(format: "%.6f", coordinate.longitude)
        
        searchResults = []
        searchText = ""
    }
    
    // 确认地图中心位置
    private func confirmMapCenter() {
        if let center = mapCenterCoordinate {
            selectedLocation = center
            manualLatitude = String(format: "%.6f", center.latitude)
            manualLongitude = String(format: "%.6f", center.longitude)
        }
    }
    
    // 确认选择并保存
    private func confirmSelection() {
        guard let location = selectedLocation else { return }
        settings.companyLatitude = location.latitude
        settings.companyLongitude = location.longitude
        dismiss()
    }
}

// 定位管理器代理（单例）
class LocationManagerDelegate: NSObject, CLLocationManagerDelegate, ObservableObject {
    static let shared = LocationManagerDelegate()
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            currentLocation = location
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("定位失败: \(error)")
    }
}

#Preview {
    let settings = ReminderSettings()
    return LocationPickerView(settings: settings)
}
