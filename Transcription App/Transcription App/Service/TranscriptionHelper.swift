//
//  TranscriptionHelper.swift
//  Transcription App
//
//  Created by Claude on 12/8/25.
//

import Foundation

/// Validates LLM response quality
enum LLMResponseValidator {

    /// Checks if an LLM response is valid
    /// - Parameter response: The LLM's response text
    /// - Returns: True if response is valid
    static func isValid(_ response: String) -> Bool {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Must not be empty and have minimum length
        guard !trimmed.isEmpty, trimmed.count >= 10 else {
            return false
        }

        return true
    }

    /// Limits response to maximum length
    /// - Parameters:
    ///   - response: The response text
    ///   - maxLength: Maximum allowed length
    /// - Returns: Trimmed response with ellipsis if needed
    static func limit(_ response: String, to maxLength: Int) -> String {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count > maxLength else {
            return trimmed
        }

        return String(trimmed.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}
