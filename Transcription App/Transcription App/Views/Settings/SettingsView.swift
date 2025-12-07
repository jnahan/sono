import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var audioLanguage: String
    @State private var showTimestamps: Bool
    @State private var transcriptionModel: String
    
    init() {
        _audioLanguage = State(initialValue: SettingsManager.shared.audioLanguage)
        _showTimestamps = State(initialValue: SettingsManager.shared.showTimestamps)
        _transcriptionModel = State(initialValue: SettingsManager.shared.transcriptionModel.capitalized)
    }
    
    // Helper function to convert English name to local name
    private func localLanguageName(for englishName: String) -> String {
        let localNames: [String: String] = [
            "Auto": "Auto",
            "Afrikaans": "Afrikaans",
            "Albanian": "Shqip",
            "Amharic": "አማርኛ",
            "Arabic": "العربية",
            "Armenian": "Հայերեն",
            "Assamese": "অসমীয়া",
            "Azerbaijani": "Azərbaycan",
            "Bashkir": "Башҡорт",
            "Belarusian": "Беларуская",
            "Bengali": "বাংলা",
            "Bosnian": "Bosanski",
            "Breton": "Brezhoneg",
            "Bulgarian": "Български",
            "Catalan": "Català",
            "Chinese": "中文",
            "Croatian": "Hrvatski",
            "Czech": "Čeština",
            "Danish": "Dansk",
            "Dutch": "Nederlands",
            "English": "English",
            "Estonian": "Eesti",
            "Faroese": "Føroyskt",
            "Finnish": "Suomi",
            "French": "Français",
            "Galician": "Galego",
            "Georgian": "ქართული",
            "German": "Deutsch",
            "Greek": "Ελληνικά",
            "Gujarati": "ગુજરાતી",
            "Haitian Creole": "Kreyòl Ayisyen",
            "Hausa": "Hausa",
            "Hawaiian": "ʻŌlelo Hawaiʻi",
            "Hebrew": "עברית",
            "Hindi": "हिन्दी",
            "Hungarian": "Magyar",
            "Icelandic": "Íslenska",
            "Indonesian": "Bahasa Indonesia",
            "Italian": "Italiano",
            "Japanese": "日本語",
            "Javanese": "Basa Jawa",
            "Kannada": "ಕನ್ನಡ",
            "Kazakh": "Қазақ",
            "Khmer": "ខ្មែរ",
            "Korean": "한국어",
            "Lao": "ລາວ",
            "Latin": "Latina",
            "Latvian": "Latviešu",
            "Lingala": "Lingála",
            "Lithuanian": "Lietuvių",
            "Luxembourgish": "Lëtzebuergesch",
            "Macedonian": "Македонски",
            "Malagasy": "Malagasy",
            "Malay": "Bahasa Melayu",
            "Malayalam": "മലയാളം",
            "Maltese": "Malti",
            "Māori": "Te Reo Māori",
            "Marathi": "मराठी",
            "Mongolian": "Монгол",
            "Burmese": "မြန်မာ",
            "Nepali": "नेपाली",
            "Norwegian": "Norsk",
            "Norwegian Nynorsk": "Norsk Nynorsk",
            "Occitan": "Occitan",
            "Pashto": "پښتو",
            "Persian": "فارسی",
            "Polish": "Polski",
            "Portuguese": "Português",
            "Punjabi": "ਪੰਜਾਬੀ",
            "Romanian": "Română",
            "Russian": "Русский",
            "Sanskrit": "संस्कृतम्",
            "Serbian": "Српски",
            "Shona": "ChiShona",
            "Sindhi": "سنڌي",
            "Sinhala": "සිංහල",
            "Slovak": "Slovenčina",
            "Slovenian": "Slovenščina",
            "Somali": "Soomaali",
            "Spanish": "Español",
            "Sundanese": "Basa Sunda",
            "Swahili": "Kiswahili",
            "Swedish": "Svenska",
            "Tagalog": "Tagalog",
            "Tajik": "Тоҷикӣ",
            "Tamil": "தமிழ்",
            "Tatar": "Татар",
            "Telugu": "తెలుగు",
            "Thai": "ไทย",
            "Tibetan": "བོད་སྐད་",
            "Turkish": "Türkçe",
            "Turkmen": "Türkmen",
            "Ukrainian": "Українська",
            "Urdu": "اردو",
            "Uzbek": "Oʻzbek",
            "Vietnamese": "Tiếng Việt",
            "Welsh": "Cymraeg",
            "Yiddish": "ייִדיש",
            "Yoruba": "Yorùbá",
            "Yue Chinese": "粵語"
        ]
        return localNames[englishName] ?? englishName
    }
    
    // Helper function to convert local name back to English name
    private func englishLanguageName(for localName: String) -> String {
        let reverseMap: [String: String] = [
            "Auto": "Auto",
            "Afrikaans": "Afrikaans",
            "Shqip": "Albanian",
            "አማርኛ": "Amharic",
            "العربية": "Arabic",
            "Հայերեն": "Armenian",
            "অসমীয়া": "Assamese",
            "Azərbaycan": "Azerbaijani",
            "Башҡорт": "Bashkir",
            "Беларуская": "Belarusian",
            "বাংলা": "Bengali",
            "Bosanski": "Bosnian",
            "Brezhoneg": "Breton",
            "Български": "Bulgarian",
            "Català": "Catalan",
            "中文": "Chinese",
            "Hrvatski": "Croatian",
            "Čeština": "Czech",
            "Dansk": "Danish",
            "Nederlands": "Dutch",
            "English": "English",
            "Eesti": "Estonian",
            "Føroyskt": "Faroese",
            "Suomi": "Finnish",
            "Français": "French",
            "Galego": "Galician",
            "ქართული": "Georgian",
            "Deutsch": "German",
            "Ελληνικά": "Greek",
            "ગુજરાતી": "Gujarati",
            "Kreyòl Ayisyen": "Haitian Creole",
            "Hausa": "Hausa",
            "ʻŌlelo Hawaiʻi": "Hawaiian",
            "עברית": "Hebrew",
            "हिन्दी": "Hindi",
            "Magyar": "Hungarian",
            "Íslenska": "Icelandic",
            "Bahasa Indonesia": "Indonesian",
            "Italiano": "Italian",
            "日本語": "Japanese",
            "Basa Jawa": "Javanese",
            "ಕನ್ನಡ": "Kannada",
            "Қазақ": "Kazakh",
            "ខ្មែរ": "Khmer",
            "한국어": "Korean",
            "ລາວ": "Lao",
            "Latina": "Latin",
            "Latviešu": "Latvian",
            "Lingála": "Lingala",
            "Lietuvių": "Lithuanian",
            "Lëtzebuergesch": "Luxembourgish",
            "Македонски": "Macedonian",
            "Malagasy": "Malagasy",
            "Bahasa Melayu": "Malay",
            "മലയാളം": "Malayalam",
            "Malti": "Maltese",
            "Te Reo Māori": "Māori",
            "मराठी": "Marathi",
            "Монгол": "Mongolian",
            "မြန်မာ": "Burmese",
            "नेपाली": "Nepali",
            "Norsk": "Norwegian",
            "Norsk Nynorsk": "Norwegian Nynorsk",
            "Occitan": "Occitan",
            "پښتو": "Pashto",
            "فارسی": "Persian",
            "Polski": "Polish",
            "Português": "Portuguese",
            "ਪੰਜਾਬੀ": "Punjabi",
            "Română": "Romanian",
            "Русский": "Russian",
            "संस्कृतम्": "Sanskrit",
            "Српски": "Serbian",
            "ChiShona": "Shona",
            "سنڌي": "Sindhi",
            "සිංහල": "Sinhala",
            "Slovenčina": "Slovak",
            "Slovenščina": "Slovenian",
            "Soomaali": "Somali",
            "Español": "Spanish",
            "Basa Sunda": "Sundanese",
            "Kiswahili": "Swahili",
            "Svenska": "Swedish",
            "Tagalog": "Tagalog",
            "Тоҷикӣ": "Tajik",
            "தமிழ்": "Tamil",
            "Татар": "Tatar",
            "తెలుగు": "Telugu",
            "ไทย": "Thai",
            "བོད་སྐད་": "Tibetan",
            "Türkçe": "Turkish",
            "Türkmen": "Turkmen",
            "Українська": "Ukrainian",
            "اردو": "Urdu",
            "Oʻzbek": "Uzbek",
            "Tiếng Việt": "Vietnamese",
            "Cymraeg": "Welsh",
            "ייִדיש": "Yiddish",
            "Yorùbá": "Yoruba",
            "粵語": "Yue Chinese"
        ]
        return reverseMap[localName] ?? localName
    }
    
    // Data for selection lists
    // All languages officially supported by WhisperKit (based on OpenAI Whisper)
    private var audioLanguages: [SelectionItem] {
        let englishNames = [
            "Auto", "Afrikaans", "Albanian", "Amharic", "Arabic", "Armenian", "Assamese",
            "Azerbaijani", "Bashkir", "Belarusian", "Bengali", "Bosnian", "Breton",
            "Bulgarian", "Catalan", "Chinese", "Croatian", "Czech", "Danish", "Dutch",
            "English", "Estonian", "Faroese", "Finnish", "French", "Galician", "Georgian",
            "German", "Greek", "Gujarati", "Haitian Creole", "Hausa", "Hawaiian",
            "Hebrew", "Hindi", "Hungarian", "Icelandic", "Indonesian", "Italian",
            "Japanese", "Javanese", "Kannada", "Kazakh", "Khmer", "Korean", "Lao",
            "Latin", "Latvian", "Lingala", "Lithuanian", "Luxembourgish", "Macedonian",
            "Malagasy", "Malay", "Malayalam", "Maltese", "Māori", "Marathi", "Mongolian",
            "Burmese", "Nepali", "Norwegian", "Norwegian Nynorsk", "Occitan", "Pashto",
            "Persian", "Polish", "Portuguese", "Punjabi", "Romanian", "Russian",
            "Sanskrit", "Serbian", "Shona", "Sindhi", "Sinhala", "Slovak", "Slovenian",
            "Somali", "Spanish", "Sundanese", "Swahili", "Swedish", "Tagalog", "Tajik",
            "Tamil", "Tatar", "Telugu", "Thai", "Tibetan", "Turkish", "Turkmen",
            "Ukrainian", "Urdu", "Uzbek", "Vietnamese", "Welsh", "Yiddish", "Yoruba",
            "Yue Chinese"
        ]
        
        return englishNames.map { englishName in
            SelectionItem(
                title: localLanguageName(for: englishName),
                description: englishName
            )
        }
    }
    
    private let modelOptions: [SelectionItem] = [
        SelectionItem(title: "Tiny", description: "Fastest"),
        SelectionItem(title: "Base", description: "Balanced"),
        SelectionItem(title: "Small", description: "Highest quality")
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
                            // Settings Section: Audio Language, Model, Timestamps
                            VStack(spacing: 0) {
                                NavigationLink(destination: SelectionListView(
                                    title: "Audio Language",
                                    items: audioLanguages,
                                    selectedItem: Binding(
                                        get: { localLanguageName(for: audioLanguage) },
                                        set: { newValue in
                                            audioLanguage = englishLanguageName(for: newValue)
                                        }
                                    )
                                )) {
                                    SettingsRow(title: "Audio language", value: localLanguageName(for: audioLanguage), imageName: "text-aa")
                                }
                                
                                NavigationLink(destination: SelectionListView(
                                    title: "Model",
                                    items: modelOptions,
                                    selectedItem: $transcriptionModel
                                )) {
                                    SettingsRow(title: "Model", value: transcriptionModel, imageName: "sparkle")
                                }
                                
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
        .onChange(of: transcriptionModel) { oldValue, newValue in
            SettingsManager.shared.transcriptionModel = newValue.lowercased()
            // Clear the current model so it reloads with the new selection
            TranscriptionService.shared.clearModelCache()
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
