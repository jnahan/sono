import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var audioLanguage: String
    @State private var showTimestamps: Bool
    
    init() {
        let settings = SettingsManager.shared
        _audioLanguage = State(initialValue: settings.audioLanguage)
        _showTimestamps = State(initialValue: settings.showTimestamps)
    }
    
    // Data for selection lists
    // All languages officially supported by WhisperKit (based on OpenAI Whisper)
    private let audioLanguages = [
        SelectionItem(emoji: nil, title: "Auto"),
        SelectionItem(emoji: nil, title: "Afrikaans"),
        SelectionItem(emoji: nil, title: "Albanian"),
        SelectionItem(emoji: nil, title: "Amharic"),
        SelectionItem(emoji: nil, title: "Arabic"),
        SelectionItem(emoji: nil, title: "Armenian"),
        SelectionItem(emoji: nil, title: "Assamese"),
        SelectionItem(emoji: nil, title: "Azerbaijani"),
        SelectionItem(emoji: nil, title: "Bashkir"),
        SelectionItem(emoji: nil, title: "Belarusian"),
        SelectionItem(emoji: nil, title: "Bengali"),
        SelectionItem(emoji: nil, title: "Bosnian"),
        SelectionItem(emoji: nil, title: "Breton"),
        SelectionItem(emoji: nil, title: "Bulgarian"),
        SelectionItem(emoji: nil, title: "Catalan"),
        SelectionItem(emoji: nil, title: "Chinese"),
        SelectionItem(emoji: nil, title: "Croatian"),
        SelectionItem(emoji: nil, title: "Czech"),
        SelectionItem(emoji: nil, title: "Danish"),
        SelectionItem(emoji: nil, title: "Dutch"),
        SelectionItem(emoji: nil, title: "English"),
        SelectionItem(emoji: nil, title: "Estonian"),
        SelectionItem(emoji: nil, title: "Faroese"),
        SelectionItem(emoji: nil, title: "Finnish"),
        SelectionItem(emoji: nil, title: "French"),
        SelectionItem(emoji: nil, title: "Galician"),
        SelectionItem(emoji: nil, title: "Georgian"),
        SelectionItem(emoji: nil, title: "German"),
        SelectionItem(emoji: nil, title: "Greek"),
        SelectionItem(emoji: nil, title: "Gujarati"),
        SelectionItem(emoji: nil, title: "Haitian Creole"),
        SelectionItem(emoji: nil, title: "Hausa"),
        SelectionItem(emoji: nil, title: "Hawaiian"),
        SelectionItem(emoji: nil, title: "Hebrew"),
        SelectionItem(emoji: nil, title: "Hindi"),
        SelectionItem(emoji: nil, title: "Hungarian"),
        SelectionItem(emoji: nil, title: "Icelandic"),
        SelectionItem(emoji: nil, title: "Indonesian"),
        SelectionItem(emoji: nil, title: "Italian"),
        SelectionItem(emoji: nil, title: "Japanese"),
        SelectionItem(emoji: nil, title: "Javanese"),
        SelectionItem(emoji: nil, title: "Kannada"),
        SelectionItem(emoji: nil, title: "Kazakh"),
        SelectionItem(emoji: nil, title: "Khmer"),
        SelectionItem(emoji: nil, title: "Korean"),
        SelectionItem(emoji: nil, title: "Lao"),
        SelectionItem(emoji: nil, title: "Latin"),
        SelectionItem(emoji: nil, title: "Latvian"),
        SelectionItem(emoji: nil, title: "Lingala"),
        SelectionItem(emoji: nil, title: "Lithuanian"),
        SelectionItem(emoji: nil, title: "Luxembourgish"),
        SelectionItem(emoji: nil, title: "Macedonian"),
        SelectionItem(emoji: nil, title: "Malagasy"),
        SelectionItem(emoji: nil, title: "Malay"),
        SelectionItem(emoji: nil, title: "Malayalam"),
        SelectionItem(emoji: nil, title: "Maltese"),
        SelectionItem(emoji: nil, title: "Māori"),
        SelectionItem(emoji: nil, title: "Marathi"),
        SelectionItem(emoji: nil, title: "Mongolian"),
        SelectionItem(emoji: nil, title: "Burmese"),
        SelectionItem(emoji: nil, title: "Nepali"),
        SelectionItem(emoji: nil, title: "Norwegian"),
        SelectionItem(emoji: nil, title: "Norwegian Nynorsk"),
        SelectionItem(emoji: nil, title: "Occitan"),
        SelectionItem(emoji: nil, title: "Pashto"),
        SelectionItem(emoji: nil, title: "Persian"),
        SelectionItem(emoji: nil, title: "Polish"),
        SelectionItem(emoji: nil, title: "Portuguese"),
        SelectionItem(emoji: nil, title: "Punjabi"),
        SelectionItem(emoji: nil, title: "Romanian"),
        SelectionItem(emoji: nil, title: "Russian"),
        SelectionItem(emoji: nil, title: "Sanskrit"),
        SelectionItem(emoji: nil, title: "Serbian"),
        SelectionItem(emoji: nil, title: "Shona"),
        SelectionItem(emoji: nil, title: "Sindhi"),
        SelectionItem(emoji: nil, title: "Sinhala"),
        SelectionItem(emoji: nil, title: "Slovak"),
        SelectionItem(emoji: nil, title: "Slovenian"),
        SelectionItem(emoji: nil, title: "Somali"),
        SelectionItem(emoji: nil, title: "Spanish"),
        SelectionItem(emoji: nil, title: "Sundanese"),
        SelectionItem(emoji: nil, title: "Swahili"),
        SelectionItem(emoji: nil, title: "Swedish"),
        SelectionItem(emoji: nil, title: "Tagalog"),
        SelectionItem(emoji: nil, title: "Tajik"),
        SelectionItem(emoji: nil, title: "Tamil"),
        SelectionItem(emoji: nil, title: "Tatar"),
        SelectionItem(emoji: nil, title: "Telugu"),
        SelectionItem(emoji: nil, title: "Thai"),
        SelectionItem(emoji: nil, title: "Tibetan"),
        SelectionItem(emoji: nil, title: "Turkish"),
        SelectionItem(emoji: nil, title: "Turkmen"),
        SelectionItem(emoji: nil, title: "Ukrainian"),
        SelectionItem(emoji: nil, title: "Urdu"),
        SelectionItem(emoji: nil, title: "Uzbek"),
        SelectionItem(emoji: nil, title: "Vietnamese"),
        SelectionItem(emoji: nil, title: "Welsh"),
        SelectionItem(emoji: nil, title: "Yiddish"),
        SelectionItem(emoji: nil, title: "Yoruba"),
        SelectionItem(emoji: nil, title: "Yue Chinese")
    ]
    
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
                            // Audio Language Section
                            VStack(spacing: 0) {
                                NavigationLink(destination: SelectionListView(
                                    title: "Audio Language",
                                    items: audioLanguages,
                                    selectedItem: $audioLanguage
                                )) {
                                    SettingsRow(title: "Audio language", value: audioLanguage, imageName: "text-aa")
                                }
                                
                                NavigationLink(destination: SelectionListView(
                                    title: "Timestamps",
                                    items: [
                                        SelectionItem(emoji: nil, title: "On"),
                                        SelectionItem(emoji: nil, title: "Off")
                                    ],
                                    selectedItem: Binding(
                                        get: { showTimestamps ? "On" : "Off" },
                                        set: { newValue in
                                            showTimestamps = (newValue == "On")
                                        }
                                    )
                                )) {
                                    HStack(spacing: 16) {
                                        Image("clock")
                                            .renderingMode(.template)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 24, height: 24)
                                            .foregroundColor(.black)
                                        
                                        Text("Timestamps")
                                            .font(.system(size: 17))
                                            .foregroundColor(.baseBlack)
                                        
                                        Spacer()
                                        
                                        Text(showTimestamps ? "On" : "Off")
                                            .font(.system(size: 17))
                                            .foregroundColor(.warmGray500)
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14))
                                            .foregroundColor(.warmGray400)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            
                            // Model Section
                            VStack(spacing: 0) {
                                SettingsRow(title: "Model", value: "Tiny", imageName: "sparkle", showChevron: false)
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
                .foregroundColor(.black)
            
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
