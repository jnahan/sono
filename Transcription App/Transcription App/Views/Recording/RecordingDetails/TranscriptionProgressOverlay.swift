import SwiftUI

struct TranscriptionProgressOverlay: View {
    let progress: Double
    let isQueued: Bool
    let queuePosition: (position: Int, total: Int)?
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            CustomTopBar(
                title: "",
                leftIcon: "caret-left",
                rightIcon: nil,
                onLeftTap: { onDismiss?() }
            )

            // White background for content area
            ZStack {
                Color.white

                VStack(spacing: 0) {
                    if isQueued {
                        VStack(spacing: 0) {
                            Text("Waiting to transcribe")
                                .font(.dmSansSemiBold(size: 24))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                            Spacer().frame(height: 8)
                            Text("Please do not close the app or turn off your display until transcription is complete.")
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
                                .foregroundColor(.black)
                            Spacer().frame(height: 16)
                            Text("Transcribing audio")
                                .font(.dmSansSemiBold(size: 24))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                            Spacer().frame(height: 8)
                            Text("Please do not close the app or turn off your display until transcription is complete.")
                                .font(.dmSansRegular(size: 16))
                                .foregroundColor(.blueGray700)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .background(Color.white.ignoresSafeArea())
    }
}
