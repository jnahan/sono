import Foundation

/// Utility for truncating transcription text to fit LLM context windows
struct TranscriptionTruncator {
    
    /// Default maximum input length for LLM prompts
    static let defaultMaxInputLength = 3000
    
    /// Truncates transcription text to fit within a maximum length
    /// If text exceeds the limit, it takes 60% from the beginning and the remainder from the end
    /// - Parameters:
    ///   - text: The full transcription text to truncate
    ///   - maxLength: Maximum length of the truncated text (default: 3000)
    /// - Returns: Truncated text with ellipsis marker if truncation occurred
    static func truncate(_ text: String, maxLength: Int = defaultMaxInputLength) -> String {
        guard text.count > maxLength else {
            return text
        }
        
        let beginningLength = Int(Double(maxLength) * 0.6)
        let endLength = maxLength - beginningLength - 50 // Reserve 50 chars for separator
        let beginning = String(text.prefix(beginningLength))
        let end = String(text.suffix(endLength))
        
        return "\(beginning)\n\n[...]\n\n\(end)"
    }
}
