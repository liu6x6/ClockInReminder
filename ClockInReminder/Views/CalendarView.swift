import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var settings: ReminderSettings
    @Query private var allCustomReminders: [CustomReminder]
    @Query private var notificationScheduleRecords: [NotificationScheduleRecord]
    @State private var currentMonth: Date = Date()
    @State private var showTodayIndicator = false
    @State private var selectedDate: Date?
    @State private var showDateDetail = false
    @State private var pendingSingleTapDate: Date?
    @State private var pendingSingleTapTask: Task<Void, Never>?
    
    private let calendar = Calendar.current
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
    private let doubleTapDelay: TimeInterval = 0.5
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - 月份导航
                monthHeaderView
                
                // MARK: - 星期标题
                weekdayHeaderView

                notificationStatusSummary
                
                // MARK: - 日历网格（支持滑动切换月份）
                calendarGridView
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                let threshold = 50.0
                                if value.translation.width < -threshold {
                                    // 向左滑动，切换到下个月
                                    withAnimation {
                                        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
                                            currentMonth = nextMonth
                                        }
                                    }
                                } else if value.translation.width > threshold {
                                    // 向右滑动，切换到上个月
                                    withAnimation {
                                        if let prevMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
                                            currentMonth = prevMonth
                                        }
                                    }
                                }
                            }
                    )
                
                // MARK: - 统计信息
                summaryView
                
                // MARK: - 操作按钮
                actionButtonsView
            }
            .navigationTitle("打卡日历")
            .onAppear {
                NotificationService.shared.scheduleAll(settings: settings, modelContext: modelContext)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation {
                            currentMonth = Date()
                            showTodayIndicator = true
                        }
                        // 2秒后隐藏指示器
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showTodayIndicator = false
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.circle.fill")
                            Text("今天")
                        }
                    }
                }
            }
            .sheet(isPresented: $showDateDetail) {
                if let date = selectedDate {
                    DateDetailView(currentDate: date, settings: settings)
                }
            }
        }
    }
    
    // 获取某天的自定义提醒数量
    private func customReminderCount(for date: Date) -> Int {
        let dateString = ReminderSettings.dateKey(date)
        return allCustomReminders.filter { $0.date == dateString }.count
    }

    private func notificationScheduleStatus(for date: Date) -> (generated: Int, total: Int) {
        let dateKey = ReminderSettings.dateKey(date)
        let records = notificationScheduleRecords.filter { $0.dateKey == dateKey }
        return (records.filter(\.isSystemScheduled).count, records.count)
    }

    private var notificationStatusSummary: some View {
        let generatedCount = notificationScheduleRecords.filter(\.isSystemScheduled).count
        let totalCount = notificationScheduleRecords.count

        return HStack(spacing: ReminderUITheme.statusSpacing) {
            if totalCount > 0 {
                NotificationScheduleIndicator(
                    generatedCount: generatedCount,
                    totalCount: totalCount,
                    showsLabel: true
                )
            } else {
                Text("暂无待生成的固定提醒")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, ReminderUITheme.statusIconPadding)
    }
    
    // 是否是过去的月份
    private var isPastMonth: Bool {
        let now = Date()
        let currentMonthComponents = calendar.dateComponents([.year, .month], from: currentMonth)
        let nowComponents = calendar.dateComponents([.year, .month], from: now)
        
        if currentMonthComponents.year! < nowComponents.year! {
            return true
        }
        if currentMonthComponents.year! == nowComponents.year! && currentMonthComponents.month! < nowComponents.month! {
            return true
        }
        return false
    }
    
    // 是否是当前显示的月份
    private var isCurrentMonth: Bool {
        calendar.isDate(currentMonth, equalTo: Date(), toGranularity: .month)
    }
    
    // 月份导航
    private var monthHeaderView: some View {
        HStack {
            Button {
                withAnimation {
                    currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .padding()
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Text(monthTitle)
                    .font(.title2.bold())
                
                if showTodayIndicator && isCurrentMonth {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.orange)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            Spacer()
            
            Button {
                withAnimation {
                    currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .padding()
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    // 星期标题
    private var weekdayHeaderView: some View {
        HStack {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }
    
    // 日历网格
    private var calendarGridView: some View {
        let days = generateDaysInMonth()
        
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(days, id: \.self) { day in
                if let day = day {
                    let isPast = isDatePast(day)
                    let isToday = calendar.isDateInToday(day)
                    let customCount = customReminderCount(for: day)
                    let notificationStatus = notificationScheduleStatus(for: day)
                    
                    DayCell(
                        date: day,
                        isScheduled: settings.isScheduled(day),
                        isConfirmed: settings.isConfirmed(day),
                        isToday: isToday,
                        isPast: isPast,
                        isCurrentMonth: calendar.isDate(day, equalTo: currentMonth, toGranularity: .month),
                        morningEnabled: settings.isMorningEnabled(on: day),
                        eveningEnabled: settings.isEveningEnabled(on: day),
                        customReminderCount: customCount,
                        generatedNotificationCount: notificationStatus.generated,
                        totalNotificationCount: notificationStatus.total
                    )
                    .onTapGesture(count: 2) {
                        // 双击：取消待处理的单击，立即打开详情页
                        pendingSingleTapTask?.cancel()
                        pendingSingleTapTask = nil
                        pendingSingleTapDate = nil
                        
                        selectedDate = day
                        showDateDetail = true
                    }
                    .onTapGesture(count: 1) {
                        // 单击：延迟执行，等待可能的双击
                        guard !isPast else { return }
                        
                        // 取消之前的待处理任务
                        pendingSingleTapTask?.cancel()
                        
                        // 记录当前点击的日期
                        pendingSingleTapDate = day
                        
                        // 启动延迟任务
                        pendingSingleTapTask = Task {
                            try? await Task.sleep(nanoseconds: UInt64(doubleTapDelay * 1_000_000_000))
                            
                            // 检查任务是否被取消
                            if Task.isCancelled { return }
                            
                            // 检查是否还是同一个日期
                            if pendingSingleTapDate == day {
                                await MainActor.run {
                                    withAnimation(.spring(response: 0.3)) {
                                        settings.toggleDate(day)
                                        NotificationService.shared.scheduleAll(settings: settings, modelContext: modelContext)
                                    }
                                    pendingSingleTapDate = nil
                                }
                            }
                        }
                    }
                    .onLongPressGesture {
                        // 长按：取消待处理的单击，确认/取消确认
                        pendingSingleTapTask?.cancel()
                        pendingSingleTapTask = nil
                        pendingSingleTapDate = nil
                        
                        withAnimation(.spring(response: 0.3)) {
                            if settings.isConfirmed(day) {
                                settings.unconfirmDate(day)
                            } else {
                                settings.confirmDate(day)
                            }
                        }
                    }
                } else {
                    Color.clear
                        .frame(height: 48)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // 统计信息
    private var summaryView: some View {
        let count = settings.scheduledCount(in: currentMonth)
        let total = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 0
        let completedCount = settings.completedCount(in: currentMonth)
        
        return VStack(spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
                Text("本月已安排 \(count) / \(total) 天打卡")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if completedCount > 0 {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("本月已确认 \(completedCount) 天打卡")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack {
                Text("💡 双击日期查看/编辑提醒")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(.top, 16)
    }
    
    // 操作按钮
    private var actionButtonsView: some View {
        HStack(spacing: 16) {
            // 全选本月工作日（只对当月有效）
            Button {
                selectAllWorkdays()
            } label: {
                Label("全选工作日", systemImage: "briefcase.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isPastMonth) // 过去月份禁用
            
            // 清空本月
            Button(role: .destructive) {
                clearMonth()
            } label: {
                Label("清空本月", systemImage: "xmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isPastMonth) // 过去月份禁用
        }
        .padding()
        .opacity(isPastMonth ? 0.5 : 1) // 过去月份半透明
    }
    
    // 月份标题
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: currentMonth)
    }
    
    // 判断日期是否已过去
    private func isDatePast(_ date: Date) -> Bool {
        let now = Date()
        // 如果是今天，检查时间是否已过
        if calendar.isDateInToday(date) {
            // 今天可以选择，但显示为特殊状态
            return false
        }
        // 比较日期（忽略时间）
        return calendar.compare(date, to: now, toGranularity: .day) == .orderedAscending
    }
    
    // 生成月份的天数（包含前置空白）
    private func generateDaysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: monthInterval.start)) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 0
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        
        for day in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: firstDay) {
                days.append(date)
            }
        }
        
        return days
    }
    
    // 全选本月工作日
    private func selectAllWorkdays() {
        // 过去月份不允许操作
        guard !isPastMonth else { return }
        
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: monthInterval.start)) else {
            return
        }
        
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 0
        
        for day in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: firstDay) {
                // 跳过已过去的日期
                if isDatePast(date) { continue }
                
                let weekday = calendar.component(.weekday, from: date)
                // 周一到周五 (2-6)
                if weekday >= 2 && weekday <= 6 && !settings.isScheduled(date) {
                    settings.toggleDate(date)
                }
            }
        }
        
        NotificationService.shared.scheduleAll(settings: settings, modelContext: modelContext)
    }
    
    // 清空本月
    private func clearMonth() {
        // 过去月份不允许操作
        guard !isPastMonth else { return }
        
        let datesToRemove = settings.scheduledDates.filter { dateStr in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: dateStr) {
                // 只清空本月的、且还没过去的日期
                let isCurrentMonthDate = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
                let isNotPast = !isDatePast(date)
                return isCurrentMonthDate && isNotPast
            }
            return false
        }
        
        settings.scheduledDates.removeAll { datesToRemove.contains($0) }
        NotificationService.shared.scheduleAll(settings: settings, modelContext: modelContext)
    }
}

// MARK: - 日期单元格
struct DayCell: View {
    let date: Date
    let isScheduled: Bool
    let isConfirmed: Bool
    let isToday: Bool
    let isPast: Bool
    let isCurrentMonth: Bool
    let morningEnabled: Bool
    let eveningEnabled: Bool
    let customReminderCount: Int
    let generatedNotificationCount: Int
    let totalNotificationCount: Int
    
    private let calendar = Calendar.current
    
    var body: some View {
        let day = calendar.component(.day, from: date)
        
        return ZStack {
            // 今天的橙色外圈（最大，在最底层）
            if isToday {
                Circle()
                    .stroke(.orange, lineWidth: 3)
                    .frame(width: 42, height: 42)
            }
            
            // 已确认的绿色圈
            if isConfirmed {
                Circle()
                    .fill(.green)
                    .frame(width: 36, height: 36)
            }
            // 已安排的蓝色圈（根据上班/下班显示半圆或全圆）
            else if isScheduled {
                reminderIndicator
            }
            
            // 自定义提醒的红色小点
            if customReminderCount > 0 && !isConfirmed {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .offset(x: 14, y: -14)
            }

            if totalNotificationCount > 0 && !isConfirmed {
                NotificationScheduleIndicator(
                    generatedCount: generatedNotificationCount,
                    totalCount: totalNotificationCount
                )
                .offset(x: 14, y: 14)
            }
            
            // 日期文字
            Text("\(day)")
                .font(.system(size: 16, weight: isScheduled || isConfirmed ? .bold : .regular))
                .foregroundStyle(textColor)
            
            // 已确认标记
            if isConfirmed {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: 12, y: -12)
            }
        }
        .frame(height: 48) // 增加高度给橙色圈留出空间
        .opacity(isPast ? 0.4 : 1)
    }
    
    // 提醒指示器（根据上班/下班显示半圆或全圆）
    @ViewBuilder
    private var reminderIndicator: some View {
        if morningEnabled && eveningEnabled {
            // 上下午都有，显示完整蓝色圆
            Circle()
                .fill(.blue)
                .frame(width: 36, height: 36)
        } else if morningEnabled {
            // 只有上午，显示左半圆
            HalfCircle(shape: .left)
                .fill(.blue)
                .frame(width: 36, height: 36)
        } else if eveningEnabled {
            // 只有下午，显示右半圆
            HalfCircle(shape: .right)
                .fill(.blue)
                .frame(width: 36, height: 36)
        }
    }
    
    private var textColor: Color {
        if isConfirmed || isScheduled {
            return .white
        }
        if isPast {
            return .secondary
        }
        if isCurrentMonth {
            return .primary
        }
        return .secondary
    }
}

// 半圆形状
enum HalfCircleShape {
    case left
    case right
}

struct HalfCircle: Shape {
    let shape: HalfCircleShape
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        switch shape {
        case .left:
            path.addArc(center: center, radius: radius, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
            path.closeSubpath()
        case .right:
            path.addArc(center: center, radius: radius, startAngle: .degrees(270), endAngle: .degrees(90), clockwise: false)
            path.closeSubpath()
        }
        
        return path
    }
}

#Preview {
    let settings = ReminderSettings()
    return CalendarView(settings: settings)
}
