import Foundation
import WhisperKit

/// Service for handling audio transcription using WhisperKit
class TranscriptionService {
    // MARK: - Singleton
    static let shared = TranscriptionService()
    
    // MARK: - Properties
    private var whisperKit: WhisperKit?
    private var currentModelName: String?
    private var isLoadingModel = false
    private var preloadTask: Task<Void, Never>? = nil
    
    // MARK: - Initialization
    private init() {
        // Preload the default model in the background
        print("🚀 [TranscriptionService] Initializing and starting model preload")
        preloadTask = Task {
            await preloadModel()
        }
    }
    
    // MARK: - Public Methods
    
    /// Preloads the selected model to reduce transcription latency
    func preloadModel() async {
        guard !isLoadingModel else {
            print("ℹ️ [TranscriptionService] Model already loading, skipping preload")
            return
        }

        let settings = SettingsManager.shared
        let modelName = settings.transcriptionModel

        // Only preload if we don't already have the model loaded
        guard whisperKit == nil || currentModelName != modelName else {
            print("ℹ️ [TranscriptionService] Model '\(modelName)' already loaded")
            return
        }

        print("📥 [TranscriptionService] Preloading model '\(modelName)'...")
        isLoadingModel = true
        defer { isLoadingModel = false }

        do {
            whisperKit = try await WhisperKit(WhisperKitConfig(model: modelName))
            currentModelName = modelName
            print("✅ [TranscriptionService] Model '\(modelName)' preloaded successfully")
        } catch {
            print("❌ [TranscriptionService] Failed to preload model: \(error)")
            // Don't throw - preloading is optional, will load on-demand during transcription
        }
    }
    
    /// Clears the cached model files to force re-download
    /// - Parameter modelName: The model name to clear (e.g., "base", "tiny"). If nil, clears all models.
    func clearModelCache(modelName: String? = nil) {
        let fileManager = FileManager.default
        var cleared = false
        
        // WhisperKit stores models in multiple possible locations
        let possibleCachePaths = [
            // Cache directory
            fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("whisperkit"),
            // Application Support directory
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("whisperkit"),
            // Documents directory (sometimes used)
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("whisperkit")
        ]
        
        for cacheURL in possibleCachePaths.compactMap({ $0 }) {
            guard fileManager.fileExists(atPath: cacheURL.path) else { continue }
            
            do {
                if let modelName = modelName {
                    // Clear specific model - try different naming patterns
                    let modelVariants = [
                        cacheURL.appendingPathComponent(modelName),
                        cacheURL.appendingPathComponent("openai/whisper-\(modelName)"),
                        cacheURL.appendingPathComponent("whisper-\(modelName)")
                    ]
                    
                    for modelURL in modelVariants {
                        if fileManager.fileExists(atPath: modelURL.path) {
                            try fileManager.removeItem(at: modelURL)
                            cleared = true
                        }
                    }
                } else {
                    // Clear all WhisperKit models
                    try fileManager.removeItem(at: cacheURL)
                    cleared = true
                }
            } catch {
                // Silently continue
            }
        }
        
        // Also clear the in-memory instance
        whisperKit = nil
        currentModelName = nil
    }
    
    // MARK: - Private Helpers
    
    /// Cleans WhisperKit timestamp tokens from text (e.g., <|9.84|>, <|en|>, <|transcribe|>)
    private func cleanTimestampTokens(from text: String) -> String {
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
                let range = NSRange(cleanedText.startIndex..., in: cleanedText)
                cleanedText = regex.stringByReplacingMatches(in: cleanedText, options: [], range: range, withTemplate: "")
            }
        }
        
        // Remove leading dashes, whitespace, and other artifacts
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        while cleanedText.hasPrefix("-") || cleanedText.hasPrefix("•") {
            cleanedText = String(cleanedText.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Remove any remaining special characters that might be tokens
        cleanedText = cleanedText.replacingOccurrences(of: "^[<|].*?[|>]", with: "", options: .regularExpression)
        
        return cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Validates if transcription text appears to be valid (not garbage output)
    private func isValidTranscription(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
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
    
    /// Transcribes an audio file and returns the result
    /// - Parameters:
    ///   - audioURL: URL of the audio file to transcribe
    ///   - modelName: Optional model name. If nil, uses the model from settings.
    ///   - languageCode: Optional language code (e.g., "en", "ko"). If nil, uses automatic detection.
    ///   - progressCallback: Optional closure called with progress updates (0.0 to 1.0)
    /// - Returns: TranscriptionResult with text, language, and segments
    /// - Throws: TranscriptionError if transcription fails
    func transcribe(audioURL: URL, modelName: String? = nil, languageCode: String? = nil, progressCallback: ((Double) -> Void)? = nil) async throws -> TranscriptionResult {
        // Use provided model or get from settings
        let settings = SettingsManager.shared
        let finalModelName = modelName ?? settings.transcriptionModel
        
        // Wait for preload to complete if it's still running
        if let task = preloadTask {
            print("⏳ [TranscriptionService] Waiting for preload to complete...")
            await task.value
            preloadTask = nil
        }

        // Initialize WhisperKit if needed
        if whisperKit == nil || currentModelName != finalModelName {
            print("📥 [TranscriptionService] Loading model '\(finalModelName)' for transcription...")
            whisperKit = nil
            currentModelName = nil

            // Report model loading progress (this is the slow part)
            if let callback = progressCallback {
                Task { @MainActor in
                    callback(0.0)
                }
            }

            do {
                whisperKit = try await WhisperKit(WhisperKitConfig(model: finalModelName))
                currentModelName = finalModelName
                print("✅ [TranscriptionService] Model '\(finalModelName)' loaded successfully")
            } catch {
                print("❌ [TranscriptionService] Failed to load model: \(error)")
                throw TranscriptionError.initializationFailed
            }
        } else {
            print("ℹ️ [TranscriptionService] Using already loaded model '\(finalModelName)'")
        }
        
        guard let whisperKit = whisperKit else {
            throw TranscriptionError.initializationFailed
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.fileNotFound
        }
        
        // Get language code from parameter or settings
        let finalLanguageCode = languageCode ?? settings.languageCode(for: settings.audioLanguage)
        
        // Perform transcription with segment-level timestamps only
        var options = DecodingOptions(wordTimestamps: false)

        if let langCode = finalLanguageCode {
            options.language = langCode
        }

        let results = try await whisperKit.transcribe(
            audioPath: audioURL.path,
            decodeOptions: options,
            callback: { progress in
                // WhisperKit provides progress through TranscriptionProgress
                // Calculate overall progress from current and total segments
                if let callback = progressCallback {
                    let currentProgress = Double(progress.timings.totalDecodingLoops)
                    // Estimate: typically ~100-300 loops for a transcription
                    // Cap at 0.95 to show progress, leave 5% for post-processing
                    let estimatedProgress = min(currentProgress / 200.0, 0.95)
                    Task { @MainActor in
                        callback(estimatedProgress)
                    }
                }
                return true // Continue transcription
            }
        )
        
        guard let firstResult = results.first else {
            throw TranscriptionError.noResults
        }
        
        // Convert to our model and clean timestamp tokens
        let segments = firstResult.segments.compactMap { segment -> TranscriptionSegment? in
            guard segment.start >= 0 && segment.end >= segment.start else {
                return nil
            }
            
            let cleanedText = cleanTimestampTokens(from: segment.text)
            let trimmed = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !trimmed.isEmpty && isValidTranscription(trimmed) else {
                return nil
            }
            
            return TranscriptionSegment(
                start: Double(segment.start),
                end: Double(segment.end),
                text: trimmed
            )
        }
        
        let cleanedFullText = cleanTimestampTokens(from: firstResult.text)
        let trimmedFullText = cleanedFullText.trimmingCharacters(in: .whitespacesAndNewlines)
        let isValidFullText = isValidTranscription(trimmedFullText)
        
        // If we have no valid segments but have valid full text, create a single segment
        var finalSegments = segments
        if finalSegments.isEmpty && isValidFullText {
            finalSegments = [
                TranscriptionSegment(
                    start: 0.0,
                    end: Double(firstResult.segments.last?.end ?? 0.0),
                    text: trimmedFullText
                )
            ]
        }
        
        // If we have no valid content, this is a transcription failure
        if finalSegments.isEmpty && !isValidFullText {
            throw TranscriptionError.noResults
        }
        
        let finalText = isValidFullText ? trimmedFullText : ""
        
        return TranscriptionResult(
            text: finalText,
            language: firstResult.language,
            segments: finalSegments
        )
    }
}

// MARK: - Models

/// Result of a transcription operation
struct TranscriptionResult {
    let text: String
    let language: String
    let segments: [TranscriptionSegment]
}

/// A time-stamped segment of transcription
struct TranscriptionSegment {
    let start: Double
    let end: Double
    let text: String
}

// MARK: - Errors

enum TranscriptionError: LocalizedError {
    case initializationFailed
    case fileNotFound
    case noResults
    
    var errorDescription: String? {
        switch self {
        case .initializationFailed:
            return "Failed to initialize transcription engine"
        case .fileNotFound:
            return "Audio file not found"
        case .noResults:
            return "No transcription results returned"
        }
    }
}
