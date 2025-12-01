import SwiftUI

struct RecordingEmptyState: View {
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 32) {
                Text("Create your \nfirst recording")
                    .font(.custom("LibreBaskerville-Medium", size: 24))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
                
                Image("curly-arrow")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 120)
            }
            .padding(.bottom, 48 + 60) // 48px above tab bar + tab bar height
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
