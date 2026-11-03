import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image("logo")
                    .resizable()
                    .frame(width: 80,height: 80)
                    .cornerRadius(18)
                
                
//                Text("牛马打卡")
//                    .font(.system(size: 30, weight: .bold))

                Text("上班本就是牛马,但是还有好好打卡")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
