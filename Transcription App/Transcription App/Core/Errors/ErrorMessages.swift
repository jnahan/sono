import Foundation

/// Centralized error messages for the app
enum ErrorMessages {
    
    // MARK: - Summary Generation
    
    enum Summary {
        static let emptyTranscription = "Cannot generate summary: transcription is empty"
        static let invalidResponse = "Model returned invalid response. Please try again"
        static let saveFailed = "Failed to save summary: %@"
        static let generationFailed = "Failed to generate summary: %@"
    }
    
    // MARK: - Transcription
    
    enum Transcription {
        static let interrupted = "Transcription was interrupted"
        static let interruptedWithDetails = "Transcription was interrupted"
        static let interruptedLowMemory = "Transcription was interrupted due to low memory"
        static let failed = "Failed to transcribe audio"
        static let failedWithDetails = "Failed to transcribe audio"
        static let cannotRetranscribe = "Failed to transcribe audio"
        static let noModelContext = "No model context configured for recovery"
        static let noAudioURL = "No audio URL for recording: %@"
        static let recordingDeleted = "Recording was deleted during transcription"
        static let recordingDeletedDuringTranscription = "Recording was deleted during transcription, skipping result update"
    }
    
    // MARK: - Validation
    
    enum Validation {
        static let titleRequired = "Title is required"
        static let titleTooLong = "Title must be less than %d characters"
        static let collectionNameRequired = "Collection name is required"
        static let collectionNameTooLong = "Collection name must be less than %d characters"
        static let duplicateCollectionName = "A collection with this name already exists"
    }
    
    // MARK: - Queue Management
    
    enum Queue {
        static let lockTimeout = "Lock timeout for operation: %@"
        static let cannotAcquireLock = "Cannot acquire lock for validation - potential deadlock"
        static let stateCorrupted = "Queue state corrupted - clearing stale activeTranscriptionId"
        static let couldNotCancel = "Could not acquire lock to cancel, attempting direct removal"
    }
    
    // MARK: - Progress Manager
    
    enum Progress {
        static let invalidProgressValue = "Invalid progress value: %f for recording: %@"
        static let invalidQueuePosition = "Invalid queue position: %d for recording: %@"
    }
    
    // MARK: - Helper Methods
    
    /// Formats an error message with a single string argument
    /// - Parameters:
    ///   - template: The message template with %@ placeholder
    ///   - argument: The string argument to substitute
    /// - Returns: Formatted error message
    static func format(_ template: String, _ argument: String) -> String {
        return String(format: template, argument)
    }
    
    /// Formats an error message with a single integer argument
    /// - Parameters:
    ///   - template: The message template with %d placeholder
    ///   - argument: The integer argument to substitute
    /// - Returns: Formatted error message
    static func format(_ template: String, _ argument: Int) -> String {
        return String(format: template, argument)
    }
    
    /// Formats an error message with a double and string argument
    /// - Parameters:
    ///   - template: The message template with %f and %@ placeholders
    ///   - doubleArg: The double argument
    ///   - stringArg: The string argument
    /// - Returns: Formatted error message
    static func format(_ template: String, _ doubleArg: Double, _ stringArg: String) -> String {
        return String(format: template, doubleArg, stringArg)
    }
    
    /// Formats an error message with an integer and string argument
    /// - Parameters:
    ///   - template: The message template with %d and %@ placeholders
    ///   - intArg: The integer argument
    ///   - stringArg: The string argument
    /// - Returns: Formatted error message
    static func format(_ template: String, _ intArg: Int, _ stringArg: String) -> String {
        return String(format: template, intArg, stringArg)
    }
}
