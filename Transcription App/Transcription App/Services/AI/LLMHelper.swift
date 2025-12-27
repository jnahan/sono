import Foundation

/// Validates LLM response quality
enum LLMResponseValidator {

    /// Checks if an LLM response is valid
    /// - Parameter response: The LLM's response text
    /// - Returns: True if response is valid
    static func isValid(_ response: String) -> Bool {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Must not be empty
        guard !trimmed.isEmpty else {
            return false
        }

        // Reject if too long (likely hallucination)
        // Summaries should be concise (max 1000 chars)
        // Q&A responses should be focused (max 2000 chars)
        guard trimmed.count <= 2000 else {
            return false
        }

        // Detect gibberish: Check for nonsense patterns
        if containsGibberish(trimmed) {
            return false
        }

        return true
    }

    /// Detects gibberish by checking for nonsense patterns
    private static func containsGibberish(_ text: String) -> Bool {
        // Check for excessive special characters or accents (sign of encoding issues)
        let specialCharCount = text.filter { char in
            let unicode = char.unicodeScalars.first?.value ?? 0
            // Check for non-ASCII, non-standard punctuation
            return unicode > 127 && unicode != 8217 && unicode != 8216 // Allow smart quotes
        }.count

        // If >10% of text is special characters, likely gibberish
        if Double(specialCharCount) / Double(text.count) > 0.1 {
            return true
        }

        // Check for excessive punctuation without spaces (gibberish pattern)
        let punctuationPattern = try? NSRegularExpression(pattern: "[,.:;!?]{3,}", options: [])
        let punctuationMatches = punctuationPattern?.numberOfMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ) ?? 0

        if punctuationMatches > 5 {
            return true
        }

        return false
    }
}
