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
    private var isModelReady = false // Track if model is fully loaded and ready
    
    // MARK: - Initialization
    private init() {
        // Preload the default model in the background
        print("🚀 [TranscriptionService] Initializing and starting model preload")
        preloadTask = Task {
            await preloadModel()
        }
    }
    
    // MARK: - Public Methods
    
    /// Checks if the model is ready for transcription
    /// Returns true if the model is loaded, warmed up, and ready to use
    var isModelReadyForTranscription: Bool {
        return whisperKit != nil && isModelReady
    }
    
    /// Checks if the model is currently being loaded/downloaded
    /// Returns true if the model is in the process of being loaded
    var isModelLoading: Bool {
        return isLoadingModel
    }
    
    /// Preloads the selected model to reduce transcription latency
    /// This fully initializes the model including loading into Metal buffers
    func preloadModel() async {
        guard !isLoadingModel else {
            print("ℹ️ [TranscriptionService] Model already loading, skipping preload")
            return
        }

        let settings = SettingsManager.shared
        let modelName = settings.transcriptionModel

        // Only preload if we don't already have the model loaded and ready
        guard whisperKit == nil || currentModelName != modelName || !isModelReady else {
            print("ℹ️ [TranscriptionService] Model '\(modelName)' already loaded and ready")
            return
        }

        print("📥 [TranscriptionService] Preloading model '\(modelName)'...")
        isLoadingModel = true
        isModelReady = false
        defer { isLoadingModel = false }

        do {
            // Create WhisperKit instance - this downloads model files if needed
            whisperKit = try await WhisperKit(WhisperKitConfig(model: modelName))
            currentModelName = modelName
            
            // CRITICAL: WhisperKit does lazy initialization. The model files are downloaded,
            // but the actual model loading (into Metal buffers, etc.) happens on first transcribe().
            // We need to "warm up" the model by doing a minimal transcription to force full initialization.
            // This ensures the model is truly ready and won't cause delays during real transcription.
            if let whisperKit = whisperKit {
                print("🔥 [TranscriptionService] Warming up model to ensure full initialization...")
                
                // Create a minimal silent audio file (1 second of silence) to warm up the model
                // This forces WhisperKit to fully load the model into memory and Metal buffers
                let tempAudioURL = createMinimalSilentAudio()
                defer {
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: tempAudioURL)
                }
                
                // SAFETY: Warm-up transcription is safe because:
                // 1. Uses isolated temp file (UUID-based, cleaned up with defer)
                // 2. Minimal audio (0.5s silence, ~16KB) - no memory concerns
                // 3. Sequential execution (no concurrent transcriptions)
                // 4. Error handling - failures don't break the service
                // 5. WhisperKit handles sequential transcriptions on same instance safely
                // 6. Warm-up happens before any real transcriptions (during app init)
                do {
                    let startTime = Date()
                    let result = try await whisperKit.transcribe(
                        audioPath: tempAudioURL.path,
                        decodeOptions: DecodingOptions(wordTimestamps: false)
                    )
                    let warmupDuration = Date().timeIntervalSince(startTime)
                    print("🔥 [TranscriptionService] Warm-up transcription completed in \(String(format: "%.2f", warmupDuration))s")
                    print("   [TranscriptionService] Warm-up result: \(result.count) segment(s)")
                    isModelReady = true
                    print("✅ [TranscriptionService] Model '\(modelName)' preloaded and warmed up successfully")
                } catch {
                    // If warm-up fails, still mark as ready since the instance exists
                    // The model will be fully initialized on first real transcription
                    // This is safe - the warm-up is an optimization, not a requirement
                    print("⚠️ [TranscriptionService] Warm-up failed but model instance exists: \(error)")
                    print("   [TranscriptionService] Will mark as ready anyway - model will initialize on first real use")
                    isModelReady = true // Mark as ready anyway to avoid reloading
                }
            } else {
                print("❌ [TranscriptionService] WhisperKit instance is nil after creation")
                isModelReady = false
            }
        } catch {
            print("❌ [TranscriptionService] Failed to preload model: \(error)")
            isModelReady = false
            // Don't throw - preloading is optional, will load on-demand during transcription
        }
    }
    
    /// Creates a minimal silent audio file for model warm-up
    /// Returns a valid WAV file with 0.5 seconds of silence (16kHz, 16-bit, mono)
    private func createMinimalSilentAudio() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("warmup_\(UUID().uuidString).wav")
        
        // Create a minimal WAV file with 0.5 seconds of silence (16kHz, 16-bit, mono)
        // This is the minimum needed to trigger WhisperKit's model initialization
        let sampleRate: UInt32 = 16000
        let duration: Double = 0.5 // 0.5 seconds (shorter = faster warm-up)
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let numSamples = UInt32(Double(sampleRate) * duration)
        let dataSize = numSamples * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        
        var fileData = Data()
        
        // RIFF header
        fileData.append("RIFF".data(using: .ascii)!)
        fileData.append(contentsOf: withUnsafeBytes(of: UInt32(36 + dataSize).littleEndian) { Data($0) })
        fileData.append("WAVE".data(using: .ascii)!)
        
        // fmt chunk
        fileData.append("fmt ".data(using: .ascii)!)
        fileData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) }) // fmt size
        fileData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // PCM format
        fileData.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        fileData.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        fileData.append(contentsOf: withUnsafeBytes(of: UInt32(UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample / 8)).littleEndian) { Data($0) }) // byte rate
        fileData.append(contentsOf: withUnsafeBytes(of: UInt16(numChannels * bitsPerSample / 8).littleEndian) { Data($0) }) // block align
        fileData.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        
        // data chunk
        fileData.append("data".data(using: .ascii)!)
        fileData.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Data($0) })
        fileData.append(Data(count: Int(dataSize))) // Silent audio data (zeros)
        
        do {
            try fileData.write(to: tempURL)
            print("✅ [TranscriptionService] Created warm-up audio file: \(tempURL.lastPathComponent)")
        } catch {
            print("❌ [TranscriptionService] Failed to create warm-up audio file: \(error)")
        }
        
        return tempURL
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
        isModelReady = false
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
            print("✅ [TranscriptionService] Preload task completed. isModelReady=\(isModelReady), currentModelName=\(currentModelName ?? "nil")")
        }

        // Initialize WhisperKit if needed
        if whisperKit == nil || currentModelName != finalModelName || !isModelReady {
            print("📥 [TranscriptionService] Loading model '\(finalModelName)' for transcription...")
            print("   [TranscriptionService] Current state: whisperKit=\(whisperKit != nil), currentModelName=\(currentModelName ?? "nil"), isModelReady=\(isModelReady)")
            whisperKit = nil
            currentModelName = nil
            isModelReady = false

            // Report model loading progress (this is the slow part)
            if let callback = progressCallback {
                Task { @MainActor in
                    callback(0.0)
                }
            }

            do {
                // Create WhisperKit instance
                whisperKit = try await WhisperKit(WhisperKitConfig(model: finalModelName))
                currentModelName = finalModelName
                
                // Warm up the model to ensure it's fully initialized
                if let whisperKit = whisperKit {
                    print("🔥 [TranscriptionService] Warming up model for first use...")
                    let tempAudioURL = createMinimalSilentAudio()
                    defer {
                        try? FileManager.default.removeItem(at: tempAudioURL)
                    }
                    do {
                        let startTime = Date()
                        let result = try await whisperKit.transcribe(
                            audioPath: tempAudioURL.path,
                            decodeOptions: DecodingOptions(wordTimestamps: false)
                        )
                        let warmupDuration = Date().timeIntervalSince(startTime)
                        print("🔥 [TranscriptionService] Warm-up transcription completed in \(String(format: "%.2f", warmupDuration))s")
                        isModelReady = true
                        print("✅ [TranscriptionService] Model warmed up successfully")
                    } catch {
                        print("⚠️ [TranscriptionService] Warm-up failed: \(error), but continuing...")
                        isModelReady = true // Mark as ready anyway
                    }
                } else {
                    isModelReady = false
                }
                
                print("✅ [TranscriptionService] Model '\(finalModelName)' loaded and ready")
            } catch {
                print("❌ [TranscriptionService] Failed to load model: \(error)")
                isModelReady = false
                throw TranscriptionError.initializationFailed
            }
        } else {
            print("ℹ️ [TranscriptionService] Using already loaded and ready model '\(finalModelName)'")
            print("   [TranscriptionService] Model state verified: whisperKit exists, modelName matches, isModelReady=true")
        }
        
        guard let whisperKit = whisperKit else {
            print("❌ [TranscriptionService] WhisperKit instance is nil after initialization check")
            throw TranscriptionError.initializationFailed
        }
        
        // Double-check: If we think the model is ready but WhisperKit still needs to load,
        // we might need to verify the model is actually initialized
        // Note: WhisperKit doesn't expose a public "isReady" property, so we rely on our flag
        
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
