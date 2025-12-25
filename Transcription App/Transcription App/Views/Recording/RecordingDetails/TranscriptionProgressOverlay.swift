import SwiftUI

struct TranscriptionProgressOverlay: View {
    let progress: Double
    let isQueued: Bool
    let queuePosition: (position: Int, total: Int)?

    var body: some View {
        ZStack {
            Color.blueGray50.ignoresSafeArea()
            VStack(spacing: 0) {
                if isQueued {
                    VStack(spacing: 0) {
                        Text("Waiting to transcribe")
                            .font(.dmSansSemiBold(size: 24))
                            .foregroundColor(.baseBlack)
                            .multilineTextAlignment(.center)
                        Spacer().frame(height: 8)
                        Text("Your recording will be transcribed when the current transcription finishes.")
                            .font(.dmSansRegular(size: 16))
                            .foregroundColor(.blueGray700)
                            .multilineTextAlignment(.center)

                        if let qp = queuePosition {
                            Spacer().frame(height: 10)
                            Text("Queue \(qp.position) of \(qp.total)")
                                .font(.dmSansRegular(size: 14))
                                .foregroundColor(.blueGray500)
                        }
                    }
                    .padding(.horizontal, 20)
                } else {
                    VStack(spacing: 0) {
                        Text("\(Int(progress * 100))%")
                            .font(.dmSansSemiBold(size: 64))
                            .foregroundColor(.baseBlack)
                        Spacer().frame(height: 8)
                        Text("Transcribing audio")
                            .font(.dmSansSemiBold(size: 24))
                            .foregroundColor(.baseBlack)
                            .multilineTextAlignment(.center)
                        Spacer().frame(height: 8)
                        Text("Transcription in progress. Please do not close.")
                            .font(.dmSansRegular(size: 16))
                            .foregroundColor(.blueGray700)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}
