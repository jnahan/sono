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
        NavigationStack {
            ZStack {
                Color.warmGray100
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
                                
                                HStack(spacing: 16) {
                                    Image("clock")
                                        .renderingMode(.template)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                        .foregroundColor(.baseBlack)

                                    Text("Timestamps")
                                        .font(.system(size: 17))
                                        .foregroundColor(.baseBlack)
                                    
                                    Spacer()
                                    
                                    CustomSwitch(isOn: $showTimestamps)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            
                            // Bottom Section: Feedback, Rate, Share
                            VStack(spacing: 0) {
                                Button(action: sendFeedback) {
                                    SettingsRow(title: "Feedback and support", value: nil, imageName: "seal-question")
                                }
                                
                                Button(action: rateApp) {
                                    SettingsRow(title: "Rate app", value: nil, imageName: "star")
                                }
                                
                                Button(action: shareApp) {
                                    SettingsRow(title: "Share app", value: nil, imageName: "export")
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                        }
                        .padding(.top, 8)
                    }
                    
                    Spacer()
                    
                    // Footer
                    VStack(spacing: 8) {
                        Image("diamond")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                        
                        Text("SONO")
                            .font(.custom("LibreBaskerville-Regular", size: 20))
                            .foregroundColor(.baseBlack)
                        
                        Text("Made with love")
                            .font(.system(size: 16))
                            .foregroundColor(.warmGray600)
                        
                        Text("Version 1.0.0")
                            .font(.system(size: 14))
                            .foregroundColor(.warmGray400)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
        .presentationDragIndicator(.hidden)
        .onChange(of: audioLanguage) { oldValue, newValue in
            SettingsManager.shared.audioLanguage = newValue
        }
        .onChange(of: showTimestamps) { oldValue, newValue in
            SettingsManager.shared.showTimestamps = newValue
        }
    }
    
    // MARK: - Functions
    func rateApp() {
        if let url = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
    
    func shareApp() {
        let appURL = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID")!
        let activityVC = UIActivityViewController(
            activityItems: ["Check out this app!", appURL],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    func sendFeedback() {
        if let url = URL(string: "mailto:support@yourapp.com?subject=Feedback") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Settings Row Component
struct SettingsRow: View {
    let title: String
    let value: String?
    let imageName: String
    var showChevron: Bool = true
    
    var body: some View {
        HStack(spacing: 16) {
            Image(imageName)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(.baseBlack)

            Text(title)
                .font(.system(size: 17))
                .foregroundColor(.baseBlack)
            
            Spacer()
            
            if let value = value {
                Text(value)
                    .font(.system(size: 17))
                    .foregroundColor(.warmGray500)
            }
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.warmGray400)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}
