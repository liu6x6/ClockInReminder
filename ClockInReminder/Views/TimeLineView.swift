import SwiftUI

struct TimeLineView: View {
    @State private var currentTime = Date()
    @State private var timer: Timer?
    
    // 工作时间范围
    private let workStartHour = 9
    private let workStartMinute = 30
    private let workEndHour = 18
    private let workEndMinute = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()
                
                // 当前时间显示（时钟样式）
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
                
                Spacer()
                
                // 时间线段
                VStack(spacing: 20) {
                    Text("工作时间")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    // 时间线段视图
                    TimeLineBar(
                        currentTime: currentTime,
                        startHour: workStartHour,
                        startMinute: workStartMinute,
                        endHour: workEndHour,
                        endMinute: workEndMinute
                    )
                    .frame(height: 80)
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
                
                Spacer()
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
    
    // MARK: - 格式化字符串
    
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
            
            // 计算当前位置百分比
            let progress: CGFloat = {
                if currentMinutes <= startMinutes {
                    return 0
                } else if currentMinutes >= endMinutes {
                    return 1
                } else {
                    return CGFloat(currentMinutes - startMinutes) / CGFloat(totalMinutes)
                }
            }()
            
            // 是否在工作时间内
            let isWorkingTime = currentMinutes >= startMinutes && currentMinutes <= endMinutes
            
            ZStack {
                // 背景线段
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: width, height: 8)
                    .position(x: width / 2, y: 30)
                
                // 已过时间线段
                Rectangle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: width * progress, height: 8)
                    .position(x: width * progress / 2, y: 30)
                
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
    
    // 获取有效的小时标记
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

// 小时标记视图
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

// 当前时间指示器
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
        .position(x: width * progress, y: 10)
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
