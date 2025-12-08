import Foundation

/// Manages app settings persistence and retrieval
class SettingsManager {
    // MARK: - Singleton
    static let shared = SettingsManager()
    
    // MARK: - Keys
    private let audioLanguageKey = "audioLanguage"
    private let showTimestampsKey = "showTimestamps"
    
    // MARK: - Defaults
    private let defaultLanguage = "Auto"
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Language Settings
    
    /// Get the selected audio language
    var audioLanguage: String {
        get {
            UserDefaults.standard.string(forKey: audioLanguageKey) ?? defaultLanguage
        }
        set {
            UserDefaults.standard.set(newValue, forKey: audioLanguageKey)
        }
    }
    
    // MARK: - Display Settings
    
    /// Whether to show timestamps in recording details
    var showTimestamps: Bool {
        get {
            // Default to true if not set
            if UserDefaults.standard.object(forKey: showTimestampsKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: showTimestampsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: showTimestampsKey)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Convert language name to WhisperKit language code
    /// Returns nil for "Auto" to enable automatic detection
    func languageCode(for languageName: String) -> String? {
        if languageName == "Auto" {
            return nil
        }
        
        // Map language names to ISO 639-1 codes used by WhisperKit
        let languageMap: [String: String] = [
            "Afrikaans": "af",
            "Albanian": "sq",
            "Amharic": "am",
            "Arabic": "ar",
            "Armenian": "hy",
            "Assamese": "as",
            "Azerbaijani": "az",
            "Bashkir": "ba",
            "Belarusian": "be",
            "Bengali": "bn",
            "Bosnian": "bs",
            "Breton": "br",
            "Bulgarian": "bg",
            "Catalan": "ca",
            "Chinese": "zh",
            "Croatian": "hr",
            "Czech": "cs",
            "Danish": "da",
            "Dutch": "nl",
            "English": "en",
            "Estonian": "et",
            "Faroese": "fo",
            "Finnish": "fi",
            "French": "fr",
            "Galician": "gl",
            "Georgian": "ka",
            "German": "de",
            "Greek": "el",
            "Gujarati": "gu",
            "Haitian Creole": "ht",
            "Hausa": "ha",
            "Hawaiian": "haw",
            "Hebrew": "he",
            "Hindi": "hi",
            "Hungarian": "hu",
            "Icelandic": "is",
            "Indonesian": "id",
            "Italian": "it",
            "Japanese": "ja",
            "Javanese": "jv",
            "Kannada": "kn",
            "Kazakh": "kk",
            "Khmer": "km",
            "Korean": "ko",
            "Lao": "lo",
            "Latin": "la",
            "Latvian": "lv",
            "Lingala": "ln",
            "Lithuanian": "lt",
            "Luxembourgish": "lb",
            "Macedonian": "mk",
            "Malagasy": "mg",
            "Malay": "ms",
            "Malayalam": "ml",
            "Maltese": "mt",
            "Māori": "mi",
            "Marathi": "mr",
            "Mongolian": "mn",
            "Burmese": "my",
            "Nepali": "ne",
            "Norwegian": "no",
            "Norwegian Nynorsk": "nn",
            "Occitan": "oc",
            "Pashto": "ps",
            "Persian": "fa",
            "Polish": "pl",
            "Portuguese": "pt",
            "Punjabi": "pa",
            "Romanian": "ro",
            "Russian": "ru",
            "Sanskrit": "sa",
            "Serbian": "sr",
            "Shona": "sn",
            "Sindhi": "sd",
            "Sinhala": "si",
            "Slovak": "sk",
            "Slovenian": "sl",
            "Somali": "so",
            "Spanish": "es",
            "Sundanese": "su",
            "Swahili": "sw",
            "Swedish": "sv",
            "Tagalog": "tl",
            "Tajik": "tg",
            "Tamil": "ta",
            "Tatar": "tt",
            "Telugu": "te",
            "Thai": "th",
            "Tibetan": "bo",
            "Turkish": "tr",
            "Turkmen": "tk",
            "Ukrainian": "uk",
            "Urdu": "ur",
            "Uzbek": "uz",
            "Vietnamese": "vi",
            "Welsh": "cy",
            "Yiddish": "yi",
            "Yoruba": "yo",
            "Yue Chinese": "yue"
        ]
        
        return languageMap[languageName]
    }
}
