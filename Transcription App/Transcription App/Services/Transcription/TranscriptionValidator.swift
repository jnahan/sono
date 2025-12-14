//
//  TranscriptionValidator.swift
//  Transcription App
//
//  Created by Claude on 12/15/25.
//

import Foundation

/// Validates and cleans transcription text output from WhisperKit
/// Removes timestamp tokens, validates text quality, and filters garbage output
final class TranscriptionValidator {

    // MARK: - Singleton

    static let shared = TranscriptionValidator()

    private init() {}

    // MARK: - Public Methods

    /// Cleans WhisperKit timestamp tokens from text (e.g., <|9.84|>, <|en|>, <|transcribe|>)
    /// - Parameter text: Raw transcription text with potential tokens
    /// - Returns: Cleaned text with tokens removed
    func cleanTimestampTokens(from text: String) -> String {
        var cleanedText = text

        // Remove all tokens matching pattern <|...|> (including nested patterns)
        let patterns = [
            "<\\|[^|]*\\|>",           // Standard tokens: <|token|>
            "<\\|\\d+\\.?\\d*\\|>",    // Timestamp tokens: <|9.84|>, <|25|>
            "<\\|[a-z]+\\|>",          // Language tokens: <|en|>, <|transcribe|>
            "<\\|startoftranscript\\|>", // Special tokens
            "<\\|endoftext\\|>",
            "<\\|notimestamps\\|>"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                // Guard against empty strings to avoid range errors
                guard !cleanedText.isEmpty else { break }
                let range = NSRange(cleanedText.startIndex..., in: cleanedText)
                cleanedText = regex.stringByReplacingMatches(in: cleanedText, options: [], range: range, withTemplate: "")
            }
        }

        // Remove leading dashes, whitespace, and other artifacts
        cleanedText = cleanedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        while cleanedText.hasPrefix("-") || cleanedText.hasPrefix("•") {
            cleanedText = String(cleanedText.dropFirst()).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }

        // Remove any remaining special characters that might be tokens
        cleanedText = cleanedText.replacingOccurrences(of: "^[<|].*?[|>]", with: "", options: .regularExpression)

        return cleanedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    /// Validates if transcription text appears to be valid (not garbage output)
    /// - Parameter text: Transcription text to validate
    /// - Returns: true if text appears valid, false if likely garbage output
    func isValidTranscription(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        // Empty or just dashes is invalid
        if trimmed.isEmpty || trimmed == "-" || trimmed == "—" {
            return false
        }

        // Check for common garbage patterns from failed transcriptions
        let garbagePatterns = [
            "^\\[+\\s*\\[+",  // Starts with multiple brackets: [[
            "^>>+",            // Starts with multiple arrows: >>
            "^\\[\\s*\\[\\s*\\[\\]",  // Pattern: [ [ []
            "^>>\\s*>>",       // Pattern: >> >>
        ]

        for pattern in garbagePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                // Guard against empty strings to avoid range errors
                guard !trimmed.isEmpty else { continue }
                let range = NSRange(trimmed.startIndex..., in: trimmed)
                if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                    return false
                }
            }
        }

        // If text is mostly brackets, arrows, or other non-letter characters, it's likely garbage
        let letterCount = trimmed.filter { $0.isLetter || $0.isNumber }.count
        let totalCount = trimmed.count
        if totalCount > 0 {
            let letterRatio = Double(letterCount) / Double(totalCount)
            // If less than 30% are letters/numbers, it's likely garbage
            if letterRatio < 0.3 && totalCount > 3 {
                return false
            }
        }

        return true
    }
}
