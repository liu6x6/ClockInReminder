import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
                
                Text("打卡提醒")
                    .font(.system(size: 30, weight: .bold))
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
