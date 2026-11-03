import SwiftUI

struct NotificationScheduleIndicator: View {
    let generatedCount: Int
    let totalCount: Int
    let showsLabel: Bool

    init(generatedCount: Int, totalCount: Int, showsLabel: Bool = false) {
        self.generatedCount = generatedCount
        self.totalCount = totalCount
        self.showsLabel = showsLabel
    }

    var body: some View {
        HStack(spacing: ReminderUITheme.statusSpacing / 2) {
            Image(systemName: generatedCount == totalCount ? "bell.fill" : "clock.fill")
                .font(.system(size: ReminderUITheme.statusIconSize, weight: .semibold))
                .foregroundStyle(generatedCount == totalCount ? ReminderUITheme.generatedColor : ReminderUITheme.waitingColor)

            if showsLabel {
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusText)
    }

    private var statusText: String {
        if generatedCount == totalCount {
            return "已生成 \(generatedCount) 条通知"
        }
        return "已生成 \(generatedCount) / \(totalCount) 条通知，剩余等待生成"
    }
}
