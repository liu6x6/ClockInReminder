import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerView: View {
    @Bindable var settings: ReminderSettings
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    
    // 手动输入经纬度
    @State private var showManualInput = false
    @State private var manualLatitude = ""
    @State private var manualLongitude = ""
    
    init(settings: ReminderSettings) {
        self.settings = settings
        
        if settings.companyLatitude != 0 {
            _selectedCoordinate = State(initialValue: CLLocationCoordinate2D(
                latitude: settings.companyLatitude,
                longitude: settings.companyLongitude
            ))
            _manualLatitude = State(initialValue: String(format: "%.6f", settings.companyLatitude))
            _manualLongitude = State(initialValue: String(format: "%.6f", settings.companyLongitude))
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
        
        selectedCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        showManualInput = false
    }
    
    private func requestLocation() {
        let manager = CLLocationManager()
        manager.delegate = LocationManagerDelegate.shared
        manager.requestWhenInUseAuthorization()
        
        if selectedCoordinate == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if let location = LocationManagerDelegate.shared.currentLocation {
                    selectedCoordinate = location.coordinate
                }
            }
        }
    }
    
    private func moveToCurrentLocation() {
        if let location = LocationManagerDelegate.shared.currentLocation {
            selectedCoordinate = location.coordinate
        } else {
            let manager = CLLocationManager()
            manager.delegate = LocationManagerDelegate.shared
            manager.startUpdatingLocation()
        }
    }
    
    private func searchLocation() {
        guard !searchText.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        
        if let current = LocationManagerDelegate.shared.currentLocation {
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
    let fenceRadius: Double
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        
        // 添加长按手势来移动标记
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.3
        mapView.addGestureRecognizer(longPress)
        
        // 如果有已保存的坐标，显示标记
        if let coord = selectedCoordinate {
            context.coordinator.addAnnotation(at: coord, on: mapView)
            
            let region = MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            mapView.setRegion(region, animated: false)
        } else {
            // 定位到当前位置
            if let location = LocationManagerDelegate.shared.currentLocation {
                let region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                mapView.setRegion(region, animated: false)
            }
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
        
        // 长按拖动标记
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            
            switch gesture.state {
            case .began:
                // 开始拖动 - 找到最近的标记
                mapView.isUserInteractionEnabled = true
                
            case .changed:
                // 拖动中 - 移动标记
                if let annotation = mapView.annotations.first(where: { $0 is MKPointAnnotation }) as? MKPointAnnotation {
                    annotation.coordinate = coordinate
                    parent.selectedCoordinate = coordinate
                    updateFenceRadius(mapView, radius: parent.fenceRadius)
                }
                
            case .ended:
                // 结束拖动
                break
                
            default:
                break
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
            view.isDraggable = true  // 关键：允许拖动
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

// 定位管理器代理（单例）
class LocationManagerDelegate: NSObject, CLLocationManagerDelegate, ObservableObject {
    static let shared = LocationManagerDelegate()
    
    @Published var currentLocation: CLLocation?
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            currentLocation = location
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}

#Preview {
    let settings = ReminderSettings()
    return LocationPickerView(settings: settings)
}
