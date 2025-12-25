import SwiftUI

struct RecordingEmptyStateView: View {
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 32) {
                Text("Create your \nfirst recording")
                    .font(.dmSansSemiBold(size: 24))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
                
                Image("curly-arrow")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 120)
            }
            .padding(.bottom, 108)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}





