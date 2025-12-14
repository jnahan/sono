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
        return LanguageMapper.languageCode(for: languageName)
    }
}
