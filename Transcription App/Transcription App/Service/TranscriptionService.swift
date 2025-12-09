import Foundation
import WhisperKit

/// Service for handling audio transcription using WhisperKit
class TranscriptionService {
    // MARK: - Singleton
    static let shared = TranscriptionService()
    
    // MARK: - Properties
    private var whisperKit: WhisperKit?
    private var isLoadingModel = false
    private var preloadTask: Task<Void, Never>? = nil
    private var isModelReady = false // Track if model is fully loaded and ready
    
    // MARK: - Queue Management (Sequential)
    private var isTranscribing: Bool = false
    private var activeTranscriptionId: UUID? = nil
    private var transcriptionQueue: [UUID] = []
    private var queuedTasks: [UUID: Task<Void, Never>] = [:]
    private let queueLock = NSLock()

    // MARK: - Constants
    private let modelName = "tiny" // Only model we support
    
    // MARK: - Queue Management Methods

    /// Safely acquire lock with timeout to prevent deadlock
    private func acquireLock(operation: String) -> Bool {
        let deadline = Date().addingTimeInterval(AppConstants.Transcription.lockTimeout)
        while !queueLock.try() {
            if Date() > deadline {
                Logger.warning("TranscriptionService", ErrorMessages.format(ErrorMessages.Queue.lockTimeout, operation))
                // Force recovery by breaking potential deadlock
                validateAndRecoverQueueState()
                return false
            }
            Thread.sleep(forTimeInterval: AppConstants.Transcription.lockRetryInterval)
        }
        return true
    }

    /// Validate queue state and recover if corrupted
    private func validateAndRecoverQueueState() {
        Logger.system("TranscriptionService", "Validating queue state")

        // Try to acquire lock, if we can't after timeout, something is very wrong
        guard queueLock.try() else {
            Logger.error("TranscriptionService", ErrorMessages.Queue.cannotAcquireLock)
            return
        }
        defer { queueLock.unlock() }

        // Check if activeTranscriptionId exists but has no active task in ProgressManager
        if let activeId = activeTranscriptionId {
            let hasActiveTask = Task { @MainActor in
                TranscriptionProgressManager.shared.hasActiveTranscription(for: activeId)
            }

            // If active ID set but no actual task, clear it
            Task {
                let isActive = await hasActiveTask.value
                if !isActive && activeTranscriptionId == activeId {
                    Logger.warning("TranscriptionService", ErrorMessages.Queue.stateCorrupted)
                    self.resetQueueState()
                }
            }
        }
    }

    /// Reset queue state (used for recovery)
    private func resetQueueState() {
        guard acquireLock(operation: "resetQueueState") else { return }
        defer { queueLock.unlock() }

        Logger.system("TranscriptionService", "Resetting queue state")
        isTranscribing = false
        activeTranscriptionId = nil

        // Process next item in queue if any
        if let nextId = transcriptionQueue.first {
            activeTranscriptionId = nextId
            isTranscribing = true
            Logger.success("TranscriptionService", "Resumed queue with recording: \(nextId.uuidString.prefix(8))")
        }
    }

    /// Cancel a transcription (removes from queue if queued, cancels if active)
    func cancelTranscription(recordingId: UUID) {
        guard acquireLock(operation: "cancelTranscription") else {
            Logger.warning("TranscriptionService", ErrorMessages.Queue.couldNotCancel)
            // Fire-and-forget notification
            Task { @MainActor in
                TranscriptionProgressManager.shared.removeFromQueue(recordingId: recordingId)
            }
            return
        }
        defer { queueLock.unlock() }

        // Remove from queue if present
        transcriptionQueue.removeAll { $0 == recordingId }
        // If this is the active transcription, it will be cancelled by the task cancellation

        // Notify progress manager (fire-and-forget, non-blocking)
        Task { @MainActor in
            TranscriptionProgressManager.shared.removeFromQueue(recordingId: recordingId)
        }
    }
    
    // MARK: - Initialization
    private init() {
        // Preload the default model in the background
        Logger.info("TranscriptionService", "Initializing and starting model preload")
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
    
    /// Checks if the model instance exists (may not be ready yet)
    var hasModelInstance: Bool {
        return whisperKit != nil
    }
    
    /// Preloads the tiny model to reduce transcription latency
    /// This fully initializes the model including loading into Metal buffers
    func preloadModel() async {
        guard !isLoadingModel else {
            Logger.info("TranscriptionService", "Model already loading, skipping preload")
            return
        }

        // Only preload if we don't already have the model loaded and ready
        guard whisperKit == nil || !isModelReady else {
            Logger.info("TranscriptionService", "Model '\(modelName)' already loaded and ready")
            return
        }

        Logger.info("TranscriptionService", "Preloading model '\(modelName)'...")
        isLoadingModel = true
        isModelReady = false
        defer { isLoadingModel = false }

        do {
            // Create WhisperKit instance - this downloads model files if needed
            whisperKit = try await WhisperKit(WhisperKitConfig(model: modelName))
            
            // CRITICAL: WhisperKit does lazy initialization. The model files are downloaded,
            // but the actual model loading (into Metal buffers, etc.) happens on first transcribe().
            // We need to "warm up" the model by doing a minimal transcription to force full initialization.
            // This ensures the model is truly ready and won't cause delays during real transcription.
            if let whisperKit = whisperKit {
                Logger.info("TranscriptionService", "Warming up model to ensure full initialization...")
                
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
                    _ = try await whisperKit.transcribe(
                        audioPath: tempAudioURL.path,
                        decodeOptions: DecodingOptions(wordTimestamps: false)
                    )
                    let warmupDuration = Date().timeIntervalSince(startTime)
                    Logger.info("TranscriptionService", "Warm-up transcription completed in \(String(format: "%.2f", warmupDuration))s")
                    isModelReady = true
                    Logger.success("TranscriptionService", "Model '\(modelName)' preloaded and warmed up successfully")
                } catch {
                    // If warm-up fails, still mark as ready since the instance exists
                    // The model will be fully initialized on first real transcription
                    // This is safe - the warm-up is an optimization, not a requirement
                    Logger.warning("TranscriptionService", "Warm-up failed but model instance exists: \(error.localizedDescription). Will mark as ready anyway - model will initialize on first real use")
                    isModelReady = true // Mark as ready anyway to avoid reloading
                }
            } else {
                Logger.error("TranscriptionService", "WhisperKit instance is nil after creation")
                isModelReady = false
            }
        } catch {
            Logger.error("TranscriptionService", "Failed to preload model: \(error.localizedDescription)")
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
            Logger.success("TranscriptionService", "Created warm-up audio file: \(tempURL.lastPathComponent)")
        } catch {
            Logger.error("TranscriptionService", "Failed to create warm-up audio file: \(error.localizedDescription)")
        }
        
        return tempURL
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
                // Guard against empty strings to avoid range errors
                guard !cleanedText.isEmpty else { break }
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
    
    /// Transcribes an audio file and returns the result
    /// Uses sequential queue to ensure only one transcription runs at a time (mobile-safe)
    /// - Parameters:
    ///   - audioURL: URL of the audio file to transcribe
    ///   - recordingId: UUID of the recording (for queue management)
    ///   - languageCode: Optional language code (e.g., "en", "ko"). If nil, uses automatic detection.
    ///   - progressCallback: Optional closure called with progress updates (0.0 to 1.0)
    /// - Returns: TranscriptionResult with text, language, and segments
    /// - Throws: TranscriptionError if transcription fails
    func transcribe(audioURL: URL, recordingId: UUID, languageCode: String? = nil, progressCallback: ((Double) -> Void)? = nil) async throws -> TranscriptionResult {
        // Check if this recording is already being transcribed or queued (with timeout)
        guard acquireLock(operation: "transcribe-check") else {
            Logger.warning("TranscriptionService", "Lock timeout checking queue state")
            throw TranscriptionError.initializationFailed
        }
        let isActive = activeTranscriptionId == recordingId
        let isQueued = transcriptionQueue.contains(recordingId)
        queueLock.unlock()

        if isActive {
            // Already transcribing this recording - this shouldn't happen, but handle gracefully
            Logger.warning("TranscriptionService", "Recording \(recordingId.uuidString.prefix(8)) is already being transcribed")
            throw TranscriptionError.initializationFailed
        }

        if isQueued {
            // Already in queue - don't add again, just wait
            Logger.info("TranscriptionService", "Recording \(recordingId.uuidString.prefix(8)) is already queued")
            // Wait until it becomes active
            var waitCount = 0
            while true {
                guard acquireLock(operation: "transcribe-wait-queued") else {
                    Logger.warning("TranscriptionService", "Lock timeout while waiting in queue")
                    throw TranscriptionError.initializationFailed
                }
                let currentActive = activeTranscriptionId
                let isNowActive = currentActive == recordingId
                queueLock.unlock()

                if isNowActive {
                    break // Our turn!
                }

                // Check if cancelled
                try Task.checkCancellation()

                // Wait a bit before checking again
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

                // Recovery: if we've been waiting too long, validate queue state
                waitCount += 1
                if waitCount > AppConstants.Transcription.waitValidationInterval {
                    Logger.warning("TranscriptionService", "Waited too long in queue, validating state")
                    validateAndRecoverQueueState()
                    waitCount = 0
                }
            }
            // Continue to transcription logic below
        }

        // If transcription is active, add to queue and wait
        guard acquireLock(operation: "transcribe-enqueue") else {
            Logger.warning("TranscriptionService", "Lock timeout trying to enqueue")
            throw TranscriptionError.initializationFailed
        }
        let shouldQueue = isTranscribing
        if shouldQueue {
            transcriptionQueue.append(recordingId)
            let queuePosition = transcriptionQueue.count
            queueLock.unlock()

            // Notify progress manager about queue position (fire-and-forget, non-blocking)
            Task { @MainActor in
                TranscriptionProgressManager.shared.addToQueue(recordingId: recordingId, position: queuePosition)
            }

            // Wait until this recording's turn
            var waitCount = 0
            while true {
                guard acquireLock(operation: "transcribe-wait-active") else {
                    Logger.warning("TranscriptionService", "Lock timeout while waiting for turn")
                    throw TranscriptionError.initializationFailed
                }
                let currentActive = activeTranscriptionId
                let isNowActive = currentActive == recordingId
                queueLock.unlock()

                if isNowActive {
                    break // Our turn!
                }

                // Check if cancelled
                try Task.checkCancellation()

                // Wait a bit before checking again
                try? await Task.sleep(nanoseconds: UInt64(AppConstants.Transcription.waitInterval * 1_000_000_000))

                // Recovery: if we've been waiting too long, validate queue state
                waitCount += 1
                if waitCount > AppConstants.Transcription.waitValidationInterval {
                    Logger.warning("TranscriptionService", "Waited too long for turn, validating state")
                    validateAndRecoverQueueState()
                    waitCount = 0
                }
            }
        } else {
            // Can start immediately
            isTranscribing = true
            activeTranscriptionId = recordingId
            queueLock.unlock()
        }
        
        // Perform the actual transcription
        defer {
            // Cleanup queue state - use if/else instead of guard/return since we're in defer
            if acquireLock(operation: "transcribe-cleanup") {
                defer { queueLock.unlock() }

                isTranscribing = false
                activeTranscriptionId = nil

                // Remove from queue if it was there
                transcriptionQueue.removeAll { $0 == recordingId }

                // Process next in queue
                if let nextId = transcriptionQueue.first {
                    activeTranscriptionId = nextId
                    isTranscribing = true
                    // Update queue positions for remaining items (fire-and-forget, non-blocking)
                    for (index, id) in transcriptionQueue.enumerated() {
                        Task { @MainActor in
                            TranscriptionProgressManager.shared.updateQueuePosition(recordingId: id, position: index + 1)
                        }
                    }
                }

                // Notify progress manager that this recording is done (fire-and-forget, non-blocking)
                Task { @MainActor in
                    TranscriptionProgressManager.shared.removeFromQueue(recordingId: recordingId)
                }
            } else {
                Logger.warning("TranscriptionService", "Lock timeout in cleanup, scheduling recovery")
                // Last resort: try to clean up queue state
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000) // Wait 0.1s
                    self.validateAndRecoverQueueState()
                }
            }
        }
        
        // Continue with existing transcription logic
        return try await performTranscription(audioURL: audioURL, languageCode: languageCode, progressCallback: progressCallback)
    }
    
    /// Internal method that performs the actual transcription
    private func performTranscription(audioURL: URL, languageCode: String? = nil, progressCallback: ((Double) -> Void)? = nil) async throws -> TranscriptionResult {
        let settings = SettingsManager.shared

        // Wait for preload to complete if it's still running
        if let task = preloadTask {
            Logger.info("TranscriptionService", "Waiting for preload to complete...")
            await task.value
            preloadTask = nil
            Logger.success("TranscriptionService", "Preload completed. whisperKit=\(whisperKit != nil), isModelReady=\(isModelReady)")
        }

        // Wait for any ongoing model loading to complete before proceeding
        // This ensures we don't start a new download if one is already in progress
        while isLoadingModel {
            Logger.info("TranscriptionService", "Waiting for model loading to complete...")
            try? await Task.sleep(nanoseconds: AppConstants.Transcription.modelWarmupWaitInterval)
        }

        // Initialize WhisperKit if needed
        if whisperKit == nil || !isModelReady {
            // Only create new instance if we don't have one
            if whisperKit == nil {
                Logger.info("TranscriptionService", "Loading model '\(modelName)' for transcription...")
                
                if let callback = progressCallback {
                    Task { @MainActor in
                        callback(0.0)
                    }
                }

                isLoadingModel = true
                isModelReady = false
                defer { isLoadingModel = false }

                do {
                    whisperKit = try await WhisperKit(WhisperKitConfig(model: modelName))
                    
                    if let whisperKit = whisperKit {
                        Logger.info("TranscriptionService", "Warming up model for first use...")
                        let tempAudioURL = createMinimalSilentAudio()
                        defer {
                            try? FileManager.default.removeItem(at: tempAudioURL)
                        }
                        do {
                            let startTime = Date()
                            _ = try await whisperKit.transcribe(
                                audioPath: tempAudioURL.path,
                                decodeOptions: DecodingOptions(wordTimestamps: false)
                            )
                            let warmupDuration = Date().timeIntervalSince(startTime)
                            Logger.info("TranscriptionService", "Warm-up transcription completed in \(String(format: "%.2f", warmupDuration))s")
                            isModelReady = true
                            Logger.success("TranscriptionService", "Model warmed up successfully")
                        } catch {
                            Logger.warning("TranscriptionService", "Warm-up failed: \(error.localizedDescription), but continuing...")
                            isModelReady = true
                        }
                    } else {
                        isModelReady = false
                    }
                    
                    Logger.success("TranscriptionService", "Model '\(modelName)' loaded and ready")
                } catch {
                    Logger.error("TranscriptionService", "Failed to load model: \(error.localizedDescription)")
                    whisperKit = nil
                    isModelReady = false
                    throw TranscriptionError.initializationFailed
                }
            } else if !isModelReady {
                // Model exists but not ready - wait for warm-up to complete
                Logger.info("TranscriptionService", "Model exists but not ready, waiting for warm-up...")
                while !isModelReady && whisperKit != nil {
                    try? await Task.sleep(nanoseconds: AppConstants.Transcription.modelWarmupWaitInterval)
                }
                if !isModelReady {
                    isModelReady = true // Proceed anyway
                }
            }
        }
        
        guard let whisperKit = whisperKit else {
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

        // Track max loops seen to ensure monotonic progress
        var maxLoopsSeen: Double = 0

        let results = try await whisperKit.transcribe(
            audioPath: audioURL.path,
            decodeOptions: options,
            callback: { progress in
                // Check for cancellation
                if Task.isCancelled {
                    return false // Stop transcription
                }
                
                // WhisperKit provides progress through TranscriptionProgress
                // Calculate overall progress from current and total segments
                if let callback = progressCallback {
                    // Use totalDecodingLoops but ensure monotonic progress
                    let currentLoops = Double(progress.timings.totalDecodingLoops)

                    // Only update if we've seen more loops (prevent backward progress)
                    if currentLoops > maxLoopsSeen {
                        maxLoopsSeen = currentLoops
                    }

                    // Estimate: typically ~100-300 loops for a transcription
                    // Cap at 0.95 to show progress, leave 5% for post-processing
                    let estimatedProgress = min(maxLoopsSeen / 200.0, 0.95)

                    Task { @MainActor in
                        // Check again before calling callback
                        if !Task.isCancelled {
                            callback(estimatedProgress)
                        }
                    }
                }
                return !Task.isCancelled // Continue transcription unless cancelled
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
        
        // For very short or silent recordings, empty results are valid and expected
        // Return empty result instead of throwing error - user may have been silent
        let finalText = isValidFullText ? trimmedFullText : ""

        // Log if we got empty results (user may have been silent - this is fine)
        if finalSegments.isEmpty && !isValidFullText {
            Logger.info("TranscriptionService", "Transcription returned empty results - recording may have been silent or very short (this is normal)")
        }

        // Report 100% completion
        if let callback = progressCallback {
            Task { @MainActor in
                callback(1.0)
            }
        }

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
