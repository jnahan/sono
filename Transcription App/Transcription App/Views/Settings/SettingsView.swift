import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var audioLanguage: String
    @State private var showTimestamps: Bool
    
    init() {
        _audioLanguage = State(initialValue: SettingsManager.shared.audioLanguage)
        _showTimestamps = State(initialValue: SettingsManager.shared.showTimestamps)
    }
    
    // Data for selection lists
    // All languages officially supported by WhisperKit (based on OpenAI Whisper)
    private var audioLanguages: [SelectionItem] {
        return LanguageMapper.allLanguages.map { englishName in
            SelectionItem(
                title: LanguageMapper.localizedName(for: englishName),
                description: englishName
            )
        }
    }
    
    var body: some View {
        ZStack {
            Color.baseWhite
                .ignoresSafeArea()

            VStack(spacing: 0) {
                CustomTopBar(
                    title: "Settings",
                    leftIcon: "caret-left",
                    onLeftTap: { dismiss() }
                )

                ScrollView {
                    VStack(spacing: 16) {
                        // Settings Section: Transcription Model, Audio Language, Timestamps
                        VStack(spacing: 0) {
                            SettingsRow(title: "Transcription model", value: "Tiny", imageName: "sparkle", showChevron: false)

                            NavigationLink(destination: SelectionListView(
                                title: "Audio Language",
                                items: audioLanguages,
                                selectedItem: Binding(
                                    get: { LanguageMapper.localizedName(for: audioLanguage) },
                                    set: { newValue in
                                        audioLanguage = LanguageMapper.englishName(for: newValue)
                                    }
                                )
                            )) {
                                SettingsRow(title: "Audio language", value: LanguageMapper.localizedName(for: audioLanguage), imageName: "text-aa")
                            }

                            SettingsRow(title: "Timestamps", value: nil, imageName: "clock", showChevron: false, toggleBinding: $showTimestamps)
                        }
                        .padding(.vertical, 4)
                        .background(Color.blueGray100)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)

                        // TODO: v2 - Add feedback, rate, and share functionality
                        // Bottom Section: Feedback, Rate, Share
//                        VStack(spacing: 0) {
//                            Button(action: sendFeedback) {
//                                SettingsRow(title: "Feedback and support", value: nil, imageName: "seal-question")
//                            }
//
//                            Button(action: rateApp) {
//                                SettingsRow(title: "Rate app", value: nil, imageName: "star")
//                            }
//
//                            Button(action: shareApp) {
//                                SettingsRow(title: "Share app", value: nil, imageName: "export")
//                            }
//                        }
//                        .padding(.vertical, 4)
//                        .background(Color.blueGray100)
//                        .cornerRadius(12)
//                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 8)
                }
                
                Spacer()
                
                // Footer
                VStack(spacing: 8) {
                    Text("SONO")
                        .font(.dmSansMedium(size: 20))
                        .foregroundColor(.baseBlack)

                    Text("Version 1.0.0")
                        .font(.system(size: 14))
                        .foregroundColor(.blueGray500)

                    HStack(spacing: 4) {
                        Button(action: openTerms) {
                            Text("Terms")
                                .font(.system(size: 14))
                                .foregroundColor(.blueGray500)
                        }

                        Text("•")
                            .font(.system(size: 14))
                            .foregroundColor(.blueGray500)

                        Button(action: openPrivacy) {
                            Text("Privacy")
                                .font(.system(size: 14))
                                .foregroundColor(.blueGray500)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBack()
        .onChange(of: audioLanguage) { oldValue, newValue in
            SettingsManager.shared.audioLanguage = newValue
        }
        .onChange(of: showTimestamps) { oldValue, newValue in
            SettingsManager.shared.showTimestamps = newValue
        }
    }

    // MARK: - Functions

    func openTerms() {
        if let url = URL(string: "https://piquant-tile-b12.notion.site/Sono-Terms-of-Service-2cd141824eed80d1b250e412bcfa0d0e") {
            UIApplication.shared.open(url)
        }
    }

    func openPrivacy() {
        if let url = URL(string: "https://piquant-tile-b12.notion.site/Sono-Privacy-Policy-2cd141824eed801082bcc5edc1878fd4") {
            UIApplication.shared.open(url)
        }
    }

    // TODO: v2 - Uncomment when adding feedback, rate, and share functionality
//    func rateApp() {
//        if let url = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID?action=write-review") {
//            UIApplication.shared.open(url)
//        }
//    }
//
//    func shareApp() {
//        let appURL = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID")!
//        let activityVC = UIActivityViewController(
//            activityItems: ["Check out this app!", appURL],
//            applicationActivities: nil
//        )
//        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
//           let rootVC = windowScene.windows.first?.rootViewController {
//            rootVC.present(activityVC, animated: true)
//        }
//    }
//
//    func sendFeedback() {
//        if let url = URL(string: "mailto:support@yourapp.com?subject=Feedback") {
//            UIApplication.shared.open(url)
//        }
//    }
}
