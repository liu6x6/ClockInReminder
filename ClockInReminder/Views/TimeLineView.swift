import SwiftUI

struct TimeLineView: View {
    @State private var currentTime = Date()
    @State private var timer: Timer?
    @State private var selectedTab = 0
    
    // 工作时间范围
    private let workStartHour = 9
    private let workStartMinute = 30
    private let workEndHour = 18
    private let workEndMinute = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 滑动切换的时钟视图
                TabView(selection: $selectedTab) {
                    // 数字时钟
                    DigitalClockView(currentTime: currentTime)
                        .tag(0)
                    
                    // 模拟时钟
                    AnalogClockView(
                        currentTime: currentTime,
                        startHour: workStartHour,
                        startMinute: workStartMinute,
                        endHour: workEndHour,
                        endMinute: workEndMinute
                    )
                    .padding(.horizontal, 20)
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .frame(height: 420)
                
                // 时间线段（只在数字时钟页面显示）
                if selectedTab == 0 {
                    VStack(spacing: 16) {
                        Text("工作时间")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        TimeLineBar(
                            currentTime: currentTime,
                            startHour: workStartHour,
                            startMinute: workStartMinute,
                            endHour: workEndHour,
                            endMinute: workEndMinute
                        )
                        .frame(height: 60)
                        .padding(.horizontal)
                        
                        // 状态提示
                        HStack(spacing: 8) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 12, height: 12)
                            Text(statusText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("时间")
            .onAppear {
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
        }
    }
    
    // MARK: - 状态文本
    
    private var statusText: String {
        let calendar = Calendar.current
        let now = calendar.dateComponents([.hour, .minute], from: currentTime)
        let currentMinutes = now.hour! * 60 + now.minute!
        
        let startMinutes = workStartHour * 60 + workStartMinute
        let endMinutes = workEndHour * 60 + workEndMinute
        
        if currentMinutes < startMinutes {
            let remaining = startMinutes - currentMinutes
            let hours = remaining / 60
            let minutes = remaining % 60
            if hours > 0 {
                return "距离上班还有 \(hours)小时\(minutes)分钟"
            } else {
                return "距离上班还有 \(minutes)分钟"
            }
        } else if currentMinutes > endMinutes {
            let elapsed = currentMinutes - endMinutes
            let hours = elapsed / 60
            let minutes = elapsed % 60
            if hours > 0 {
                return "下班已 \(hours)小时\(minutes)分钟"
            } else {
                return "下班已 \(minutes)分钟"
            }
        } else {
            let remaining = endMinutes - currentMinutes
            let hours = remaining / 60
            let minutes = remaining % 60
            if hours > 0 {
                return "距离下班还有 \(hours)小时\(minutes)分钟"
            } else {
                return "距离下班还有 \(minutes)分钟"
            }
        }
    }
    
    private var statusColor: Color {
        let calendar = Calendar.current
        let now = calendar.dateComponents([.hour, .minute], from: currentTime)
        let currentMinutes = now.hour! * 60 + now.minute!
        
        let startMinutes = workStartHour * 60 + workStartMinute
        let endMinutes = workEndHour * 60 + workEndMinute
        
        if currentMinutes < startMinutes {
            return .blue
        } else if currentMinutes > endMinutes {
            return .gray
        } else {
            return .green
        }
    }
    
    // MARK: - 定时器
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - 数字时钟视图
struct DigitalClockView: View {
    let currentTime: Date
    
    var body: some View {
        VStack(spacing: 16) {
            // 数字时钟
            Text(timeString)
                .font(.system(size: 72, weight: .thin, design: .monospaced))
                .foregroundStyle(.primary)
            
            // 日期
            Text(dateString)
                .font(.title3)
                .foregroundStyle(.secondary)
            
            // 星期
            Text(weekdayString)
                .font(.title2)
                .foregroundStyle(.blue)
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: currentTime)
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: currentTime)
    }
    
    private var weekdayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: currentTime)
    }
}

// MARK: - 模拟时钟视图
struct AnalogClockView: View {
    let currentTime: Date
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height) - 40
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = size / 2
            
            ZStack {
                // 表盘背景
                Circle()
                    .fill(Color(.systemBackground))
                    .shadow(radius: 5)
                
                // 表盘边框
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                
                // 工作时间进度弧
                WorkTimeArc(
                    currentTime: currentTime,
                    startHour: startHour,
                    startMinute: startMinute,
                    endHour: endHour,
                    endMinute: endMinute,
                    center: center,
                    radius: radius - 15
                )
                
                // 小时刻度
                ForEach(1...12, id: \.self) { hour in
                    HourTick(hour: hour, center: center, radius: radius)
                }
                
                // 分钟刻度
                ForEach(0..<60, id: \.self) { minute in
                    if minute % 5 != 0 {
                        MinuteTick(minute: minute, center: center, radius: radius)
                    }
                }
                
                // 时针
                HourHand(time: currentTime, center: center, radius: radius * 0.5)
                
                // 分针
                MinuteHand(time: currentTime, center: center, radius: radius * 0.7)
                
                // 秒针
                SecondHand(time: currentTime, center: center, radius: radius * 0.8)
                
                // 中心点
                Circle()
                    .fill(.red)
                    .frame(width: 12, height: 12)
                
                // 日期显示
                VStack(spacing: 2) {
                    Text(dateText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(weekdayText)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .position(x: center.x, y: center.y + radius * 0.35)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: currentTime)
    }
    
    private var weekdayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: currentTime)
    }
}

// MARK: - 工作时间进度弧
struct WorkTimeArc: View {
    let currentTime: Date
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int
    let center: CGPoint
    let radius: CGFloat
    
    var body: some View {
        let calendar = Calendar.current
        let now = calendar.dateComponents([.hour, .minute], from: currentTime)
        let currentMinutes = now.hour! * 60 + now.minute!
        
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute
        
        // 将工作时间映射到表盘角度（从12点方向开始，顺时针）
        // 9:30 对应的位置
        let startAngle = timeToAngle(hour: startHour, minute: startMinute)
        let endAngle = timeToAngle(hour: endHour, minute: endMinute)
        
        // 当前时间对应的角度
        let currentAngle = timeToAngle(hour: now.hour!, minute: now.minute!)
        
        ZStack {
            // 背景弧（完整工作时间范围）
            ArcShape(
                startAngle: startAngle,
                endAngle: endAngle,
                center: center,
                radius: radius
            )
            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
            
            // 已过时间弧
            if currentMinutes >= startMinutes && currentMinutes <= endMinutes {
                ArcShape(
                    startAngle: startAngle,
                    endAngle: currentAngle,
                    center: center,
                    radius: radius
                )
                .stroke(Color.green.opacity(0.6), lineWidth: 8)
            } else if currentMinutes > endMinutes {
                // 已完成全部
                ArcShape(
                    startAngle: startAngle,
                    endAngle: endAngle,
                    center: center,
                    radius: radius
                )
                .stroke(Color.green.opacity(0.6), lineWidth: 8)
            }
            
            // 开始时间标记
            ArcMarker(angle: startAngle, center: center, radius: radius, label: "\(startHour):\(String(format: "%02d", startMinute))")
            
            // 结束时间标记
            ArcMarker(angle: endAngle, center: center, radius: radius, label: "\(endHour):\(String(format: "%02d", endMinute))")
            
            // 当前时间指示点
            if currentMinutes >= startMinutes && currentMinutes <= endMinutes {
                Circle()
                    .fill(.orange)
                    .frame(width: 12, height: 12)
                    .shadow(color: .orange.opacity(0.5), radius: 3)
                    .position(pointOnArc(angle: currentAngle, center: center, radius: radius))
            }
        }
    }
    
    // 将时间转换为表盘角度（0度为12点方向，顺时针）
    private func timeToAngle(hour: Int, minute: Int) -> Angle {
        let totalMinutes = hour * 60 + minute
        let degrees = Double(totalMinutes) / 720.0 * 360.0 - 90.0 // 12小时一圈，减去90度让0度指向12点
        return .degrees(degrees)
    }
    
    // 计算弧上的点坐标
    private func pointOnArc(angle: Angle, center: CGPoint, radius: CGFloat) -> CGPoint {
        let radians = angle.radians
        let x = center.x + radius * cos(radians)
        let y = center.y + radius * sin(radians)
        return CGPoint(x: x, y: y)
    }
}

// 弧形形状
struct ArcShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let center: CGPoint
    let radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

// 弧形标记
struct ArcMarker: View {
    let angle: Angle
    let center: CGPoint
    let radius: CGFloat
    let label: String
    
    var body: some View {
        let point = pointOnArc()
        
        VStack(spacing: 2) {
            Circle()
                .fill(.blue)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .position(x: point.x, y: point.y - 15)
    }
    
    private func pointOnArc() -> CGPoint {
        let radians = angle.radians
        let x = center.x + radius * cos(radians)
        let y = center.y + radius * sin(radians)
        return CGPoint(x: x, y: y)
    }
}

// MARK: - 时钟指针
struct HourHand: View {
    let time: Date
    let center: CGPoint
    let radius: CGFloat
    
    var body: some View {
        let angle = hourAngle()
        
        Capsule()
            .fill(.primary)
            .frame(width: 6, height: radius)
            .offset(y: -radius / 2)
            .rotationEffect(angle)
            .position(center)
    }
    
    private func hourAngle() -> Angle {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let hour = components.hour! % 12
        let minute = components.minute!
        let degrees = Double(hour) * 30 + Double(minute) * 0.5
        return .degrees(degrees)
    }
}

struct MinuteHand: View {
    let time: Date
    let center: CGPoint
    let radius: CGFloat
    
    var body: some View {
        let angle = minuteAngle()
        
        Capsule()
            .fill(.primary)
            .frame(width: 4, height: radius)
            .offset(y: -radius / 2)
            .rotationEffect(angle)
            .position(center)
    }
    
    private func minuteAngle() -> Angle {
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: time)
        let degrees = Double(minute) * 6
        return .degrees(degrees)
    }
}

struct SecondHand: View {
    let time: Date
    let center: CGPoint
    let radius: CGFloat
    
    var body: some View {
        let angle = secondAngle()
        
        Rectangle()
            .fill(.red)
            .frame(width: 2, height: radius)
            .offset(y: -radius / 2)
            .rotationEffect(angle)
            .position(center)
    }
    
    private func secondAngle() -> Angle {
        let calendar = Calendar.current
        let second = calendar.component(.second, from: time)
        let degrees = Double(second) * 6
        return .degrees(degrees)
    }
}

// MARK: - 刻度
struct HourTick: View {
    let hour: Int
    let center: CGPoint
    let radius: CGFloat
    
    var body: some View {
        let angle = Angle.degrees(Double(hour) * 30 - 90)
        let point = pointOnCircle(angle: angle, center: center, radius: radius - 20)
        
        Text("\(hour)")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.primary)
            .position(point)
    }
    
    private func pointOnCircle(angle: Angle, center: CGPoint, radius: CGFloat) -> CGPoint {
        let radians = angle.radians
        let x = center.x + radius * cos(radians)
        let y = center.y + radius * sin(radians)
        return CGPoint(x: x, y: y)
    }
}

struct MinuteTick: View {
    let minute: Int
    let center: CGPoint
    let radius: CGFloat
    
    var body: some View {
        let angle = Angle.degrees(Double(minute) * 6 - 90)
        let startPoint = pointOnCircle(angle: angle, center: center, radius: radius - 8)
        let endPoint = pointOnCircle(angle: angle, center: center, radius: radius - 3)
        
        Path { path in
            path.move(to: startPoint)
            path.addLine(to: endPoint)
        }
        .stroke(Color.secondary, lineWidth: 1)
    }
    
    private func pointOnCircle(angle: Angle, center: CGPoint, radius: CGFloat) -> CGPoint {
        let radians = angle.radians
        let x = center.x + radius * cos(radians)
        let y = center.y + radius * sin(radians)
        return CGPoint(x: x, y: y)
    }
}

// MARK: - 时间线段视图
struct TimeLineBar: View {
    let currentTime: Date
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            let startMinutes = startHour * 60 + startMinute
            let endMinutes = endHour * 60 + endMinute
            let totalMinutes = endMinutes - startMinutes
            
            let calendar = Calendar.current
            let now = calendar.dateComponents([.hour, .minute], from: currentTime)
            let currentMinutes = now.hour! * 60 + now.minute!
            
            let progress: CGFloat = {
                if currentMinutes <= startMinutes {
                    return 0
                } else if currentMinutes >= endMinutes {
                    return 1
                } else {
                    return CGFloat(currentMinutes - startMinutes) / CGFloat(totalMinutes)
                }
            }()
            
            let isWorkingTime = currentMinutes >= startMinutes && currentMinutes <= endMinutes
            
            ZStack {
                // 背景线段
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: width, height: 8)
                    .position(x: width / 2, y: 20)
                
                // 已过时间线段
                Rectangle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: width * progress, height: 8)
                    .position(x: width * progress / 2, y: 20)
                
                // 小时标记
                ForEach(validHours, id: \.self) { hour in
                    HourMarkView(hour: hour, startMinutes: startMinutes, totalMinutes: totalMinutes, width: width, height: height)
                }
                
                // 当前时间指示点
                if isWorkingTime {
                    CurrentTimeIndicator(time: currentTime, progress: progress, width: width)
                }
            }
        }
    }
    
    private var validHours: [Int] {
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute
        
        var hours: [Int] = []
        for hour in startHour...endHour {
            let hourMinutes = hour * 60
            if hourMinutes >= startMinutes && hourMinutes <= endMinutes {
                hours.append(hour)
            }
        }
        return hours
    }
}

struct HourMarkView: View {
    let hour: Int
    let startMinutes: Int
    let totalMinutes: Int
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        let hourMinutes = hour * 60
        let position = CGFloat(hourMinutes - startMinutes) / CGFloat(totalMinutes)
        
        VStack(spacing: 4) {
            Rectangle()
                .fill(Color.secondary)
                .frame(width: 1, height: 12)
            
            Text("\(hour):00")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .position(x: width * position, y: height - 10)
    }
}

struct CurrentTimeIndicator: View {
    let time: Date
    let progress: CGFloat
    let width: CGFloat
    
    var body: some View {
        VStack(spacing: 4) {
            Text(formatTime(time))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.orange)
            
            Circle()
                .fill(.orange)
                .frame(width: 16, height: 16)
                .shadow(color: .orange.opacity(0.5), radius: 4)
        }
        .position(x: width * progress, y: 0)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    TimeLineView()
}
