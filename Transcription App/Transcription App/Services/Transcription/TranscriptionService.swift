import Foundation
import WhisperKit
import AVFoundation

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
    private var activeTranscriptionTask: Task<TranscriptionResult, Error>? = nil // Store active transcription task for cancellation
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
    /// Validates and recovers queue state if corrupted
    /// CRITICAL: Properly handles lock acquisition/release to prevent race conditions
    private func validateAndRecoverQueueState() {
        Logger.system("TranscriptionService", "Validating queue state")

        guard queueLock.try() else {
            Logger.error("TranscriptionService", ErrorMessages.Queue.cannotAcquireLock)
            return
        }

        // Capture state atomically while holding lock
        let activeId = activeTranscriptionId
        queueLock.unlock()

        if let activeId = activeId {
            Task {
                let isActive = await MainActor.run {
                    TranscriptionProgressManager.shared.hasActiveTranscription(for: activeId)
                }

                if !isActive {
                    guard self.acquireLock(operation: "validateAndRecover-modify") else {
                        Logger.warning("TranscriptionService", "Could not acquire lock to fix corrupted state")
                        return
                    }
                    defer { self.queueLock.unlock() }

                    // CRITICAL: Double-check state hasn't changed while waiting for lock
                    guard self.activeTranscriptionId == activeId else {
                        Logger.info("TranscriptionService", "Queue state changed during validation - already recovered")
                        return
                    }

                    Logger.warning("TranscriptionService", ErrorMessages.Queue.stateCorrupted)

                    // Reset state
                    self.activeTranscriptionTask?.cancel()
                    self.activeTranscriptionTask = nil
                    self.isTranscribing = false
                    self.activeTranscriptionId = nil

                    // Process next in queue
                    if let nextId = self.transcriptionQueue.first {
                        self.transcriptionQueue.removeFirst()
                        self.activeTranscriptionId = nextId
                        self.isTranscribing = true
                        Logger.success("TranscriptionService", "Resumed queue with recording: \(nextId.uuidString.prefix(8))")
                    }
                }
            }
        }
    }

    /// Reset queue state (used for recovery)
    private func resetQueueState() {
        guard acquireLock(operation: "resetQueueState") else { return }
        defer { queueLock.unlock() }

        Logger.system("TranscriptionService", "Resetting queue state")
        // Cancel any active transcription task
        activeTranscriptionTask?.cancel()
        activeTranscriptionTask = nil
        isTranscribing = false
        activeTranscriptionId = nil

        // Process next item in queue if any
        if let nextId = transcriptionQueue.first {
            activeTranscriptionId = nextId
            isTranscribing = true
            Logger.success("TranscriptionService", "Resumed queue with recording: \(nextId.uuidString.prefix(8))")
        }
    }

    /// Force recovery for a specific recording when normal cancellation fails
    /// This ensures both TranscriptionService queue and ProgressManager are cleaned
    private func forceRecoveryForRecording(_ recordingId: UUID) async {
        Logger.warning("TranscriptionService", "Attempting force recovery for \(recordingId.uuidString.prefix(8))")

        // Wait a bit for any ongoing operations to complete
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        // Try to acquire lock with retry
        var attempts = 0
        while attempts < 3 {
            if acquireLock(operation: "forceRecovery") {
                // Successfully got lock, clean the queue
                transcriptionQueue.removeAll { $0 == recordingId }

                // If this is the active transcription, cancel it
                if activeTranscriptionId == recordingId {
                    activeTranscriptionTask?.cancel()
                    activeTranscriptionTask = nil
                    isTranscribing = false
                    activeTranscriptionId = nil

                    // Process next in queue
                    if let nextId = transcriptionQueue.first {
                        transcriptionQueue.removeFirst()
                        activeTranscriptionId = nextId
                        isTranscribing = true
                    }
                }

                queueLock.unlock()

                // Clean ProgressManager synchronously
                await MainActor.run {
                    TranscriptionProgressManager.shared.removeFromQueue(recordingId: recordingId)
                }

                Logger.success("TranscriptionService", "Force recovery completed for \(recordingId.uuidString.prefix(8))")
                return
            }

            attempts += 1
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds between retries
        }

        // If we still can't get lock after retries, just clean ProgressManager
        Logger.error("TranscriptionService", "Force recovery failed to acquire lock after 3 attempts for \(recordingId.uuidString.prefix(8))")
        await MainActor.run {
            TranscriptionProgressManager.shared.removeFromQueue(recordingId: recordingId)
        }
    }

    /// Cancel a transcription (removes from queue if queued, cancels if active)
    func cancelTranscription(recordingId: UUID) async {
        guard acquireLock(operation: "cancelTranscription") else {
            Logger.warning("TranscriptionService", ErrorMessages.Queue.couldNotCancel)
            // CRITICAL: If we can't get the lock, force recovery to clean both queues
            // This prevents zombie queue entries
            Logger.warning("TranscriptionService", "Forcing recovery for \(recordingId.uuidString.prefix(8)) due to lock timeout")
            await forceRecoveryForRecording(recordingId)
            return
        }

        // Remove from queue
        transcriptionQueue.removeAll { $0 == recordingId }

        // Cancel active task if this is the active transcription
        if activeTranscriptionId == recordingId {
            Logger.info("TranscriptionService", "Cancelling active transcription for: \(recordingId.uuidString.prefix(8))")
            activeTranscriptionTask?.cancel()

            // Brief wait for cancellation to propagate to WhisperKit
            // This ensures clean shutdown and prevents undefined state
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }

        queueLock.unlock()

        // Notify progress manager synchronously
        await MainActor.run {
            TranscriptionProgressManager.shared.removeFromQueue(recordingId: recordingId)
        }
    }
    
    // MARK: - Initialization
    private init() {
        // Clean up any leftover warm-up files from previous sessions
        cleanupOldWarmupFiles()

        // Preload the default model in the background
        Logger.info("TranscriptionService", "Initializing and starting model preload")
        preloadTask = Task {
            await preloadModel()
        }
    }

    /// Cleans up old warm-up audio files from previous sessions
    private func cleanupOldWarmupFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        do {
            let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            let warmupFiles = files.filter { $0.lastPathComponent.hasPrefix("warmup_") }

            for file in warmupFiles {
                try? FileManager.default.removeItem(at: file)
            }

            if !warmupFiles.isEmpty {
                Logger.info("TranscriptionService", "Cleaned up \(warmupFiles.count) old warm-up file(s)")
            }
        } catch {
            Logger.warning("TranscriptionService", "Failed to clean up old warm-up files: \(error.localizedDescription)")
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
                let warmupSuccess = await warmUpModel(whisperKit)
                isModelReady = true

                if warmupSuccess {
                    Logger.success("TranscriptionService", "Model '\(modelName)' preloaded and warmed up successfully")
                } else {
                    Logger.warning("TranscriptionService", "Model preloaded but warm-up failed - will initialize on first use")
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
        let duration = AppConstants.Transcription.warmupAudioDuration // Shorter = faster warm-up
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let numSamples = UInt32(Double(sampleRate) * duration)
        let dataSize = numSamples * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        
        var fileData = Data()

        // Create WAV header safely
        guard let riffData = "RIFF".data(using: .ascii),
              let waveData = "WAVE".data(using: .ascii),
              let fmtData = "fmt ".data(using: .ascii),
              let dataHeader = "data".data(using: .ascii) else {
            Logger.error("TranscriptionService", "Failed to encode WAV header strings")
            return tempURL
        }

        // RIFF header
        fileData.append(riffData)
        fileData.append(contentsOf: withUnsafeBytes(of: UInt32(36 + dataSize).littleEndian) { Data($0) })
        fileData.append(waveData)

        // fmt chunk
        fileData.append(fmtData)
        fileData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) }) // fmt size
        fileData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // PCM format
        fileData.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        fileData.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        fileData.append(contentsOf: withUnsafeBytes(of: UInt32(UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample / 8)).littleEndian) { Data($0) }) // byte rate
        fileData.append(contentsOf: withUnsafeBytes(of: UInt16(numChannels * bitsPerSample / 8).littleEndian) { Data($0) }) // block align
        fileData.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })

        // data chunk
        fileData.append(dataHeader)
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

    /// Warms up WhisperKit model by performing minimal silent audio transcription
    /// This forces full model initialization into Metal buffers
    /// - Parameter whisperKit: The WhisperKit instance to warm up
    /// - Returns: true if warm-up succeeded, false if failed (non-fatal)
    private func warmUpModel(_ whisperKit: WhisperKit) async -> Bool {
        Logger.info("TranscriptionService", "Warming up model to ensure full initialization...")

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
            return true
        } catch {
            Logger.warning("TranscriptionService", "Warm-up failed: \(error.localizedDescription)")
            return false
        }
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
        cleanedText = cleanedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        while cleanedText.hasPrefix("-") || cleanedText.hasPrefix("•") {
            cleanedText = String(cleanedText.dropFirst()).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
        
        // Remove any remaining special characters that might be tokens
        cleanedText = cleanedText.replacingOccurrences(of: "^[<|].*?[|>]", with: "", options: .regularExpression)
        
        return cleanedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    /// Validates if transcription text appears to be valid (not garbage output)
    private func isValidTranscription(_ text: String) -> Bool {
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

    /// Waits for a recording to become the active transcription
    /// Uses dynamic timeout based on audio duration
    /// - Parameters:
    ///   - recordingId: The recording ID to wait for
    ///   - audioURL: URL to audio file (for duration calculation)
    /// - Throws: TranscriptionError if timeout or lock failure
    private func waitForActiveTranscription(recordingId: UUID, audioURL: URL) async throws {
        // Calculate dynamic timeout based on audio duration
        let audioDuration: TimeInterval
        do {
            let asset = AVAsset(url: audioURL)
            let duration = try await asset.load(.duration)
            audioDuration = CMTimeGetSeconds(duration)
        } catch {
            audioDuration = 60 // Default fallback
        }

        let estimatedTranscriptionTime = audioDuration * 0.3
        let maxWaitChecks = max(Int(estimatedTranscriptionTime * 3 / AppConstants.Transcription.waitInterval), 1000)

        var waitCount = 0
        while true {
            guard acquireLock(operation: "transcribe-wait") else {
                Logger.warning("TranscriptionService", "Lock timeout while waiting for turn")
                throw TranscriptionError.initializationFailed
            }

            let currentActive = activeTranscriptionId
            let isNowActive = currentActive == recordingId
            queueLock.unlock()

            if isNowActive {
                break // Our turn!
            }

            try Task.checkCancellation()
            try? await Task.sleep(nanoseconds: UInt64(AppConstants.Transcription.waitInterval * 1_000_000_000))

            waitCount += 1
            if waitCount > maxWaitChecks {
                Logger.warning("TranscriptionService", "Waited too long, validating state")
                validateAndRecoverQueueState()
                waitCount = 0
            }
        }
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
        // Atomically check and enqueue/start to prevent race conditions
        guard acquireLock(operation: "transcribe-enqueue") else {
            Logger.warning("TranscriptionService", "Lock timeout trying to enqueue")
            throw TranscriptionError.initializationFailed
        }
        
        // Check current state atomically
        let isActive = activeTranscriptionId == recordingId
        let isQueued = transcriptionQueue.contains(recordingId)
        let shouldQueue = isTranscribing && !isActive
        
        if isActive {
            // Already transcribing this recording - this shouldn't happen, but handle gracefully
            queueLock.unlock()
            Logger.warning("TranscriptionService", "Recording \(recordingId.uuidString.prefix(8)) is already being transcribed")
            throw TranscriptionError.initializationFailed
        }
        
        if isQueued {
            // Already in queue - unlock and wait for our turn
            queueLock.unlock()
            Logger.info("TranscriptionService", "Recording \(recordingId.uuidString.prefix(8)) is already queued, waiting...")

            try await waitForActiveTranscription(recordingId: recordingId, audioURL: audioURL)
            // Continue to transcription logic below - we're now active
        } else if shouldQueue {
            // Need to add to queue - do it atomically
            transcriptionQueue.append(recordingId)
            let queuePosition = transcriptionQueue.count
            let totalInQueue = transcriptionQueue.count + 1 // +1 for active transcription

            // CRITICAL: Notify progress manager synchronously BEFORE unlocking
            // This ensures UI state updates atomically with queue state
            await MainActor.run {
                Logger.info("TranscriptionService", "Adding \(recordingId.uuidString.prefix(8)) to queue at position \(queuePosition)")
                TranscriptionProgressManager.shared.addToQueue(recordingId: recordingId, position: queuePosition)
            }

            queueLock.unlock()

            try await waitForActiveTranscription(recordingId: recordingId, audioURL: audioURL)
        } else {
            // Can start immediately - atomically set state
            isTranscribing = true
            activeTranscriptionId = recordingId
            let totalInQueue = transcriptionQueue.count + 1 // Current total

            // CRITICAL: Notify progress manager synchronously BEFORE unlocking
            // This ensures UI state updates atomically with queue state
            await MainActor.run {
                Logger.info("TranscriptionService", "Starting transcription immediately for \(recordingId.uuidString.prefix(8))")
                TranscriptionProgressManager.shared.setActiveTranscription(recordingId: recordingId)
            }

            queueLock.unlock()
        }
        
        // Wrap transcription in Task so we can cancel it
        let transcriptionTask = Task {
            try await performTranscription(audioURL: audioURL, languageCode: languageCode, progressCallback: progressCallback)
        }

        // Store task for cancellation
        if acquireLock(operation: "transcribe-store-task") {
            activeTranscriptionTask = transcriptionTask
            queueLock.unlock()
        }

        // Await transcription and handle cleanup
        let result: TranscriptionResult
        do {
            result = try await transcriptionTask.value
        } catch {
            // Cleanup on error
            await cleanupAndProcessNext(recordingId: recordingId, transcriptionTask: transcriptionTask)
            throw error
        }

        // Cleanup on success
        await cleanupAndProcessNext(recordingId: recordingId, transcriptionTask: transcriptionTask)
        return result
    }

    /// Cleanup after transcription and process next item in queue
    /// CRITICAL: This method ensures atomic state updates to prevent race conditions
    /// All state changes happen synchronously to maintain consistency between TranscriptionService and ProgressManager
    private func cleanupAndProcessNext(recordingId: UUID, transcriptionTask: Task<TranscriptionResult, Error>) async {
        guard acquireLock(operation: "transcribe-cleanup") else {
            Logger.warning("TranscriptionService", "Lock timeout in cleanup, forcing recovery")
            try? await Task.sleep(nanoseconds: 100_000_000)
            validateAndRecoverQueueState()
            return
        }

        // Clear active task
        if activeTranscriptionTask == transcriptionTask {
            activeTranscriptionTask = nil
        }

        // Remove this recording from queue if it's still there
        transcriptionQueue.removeAll { $0 == recordingId }

        // Clear active state
        isTranscribing = false
        activeTranscriptionId = nil

        // Get next item before unlocking (if any)
        let nextId = transcriptionQueue.first

        // If there's a next item, remove it from queue and mark as active
        if nextId != nil {
            transcriptionQueue.removeFirst()
            activeTranscriptionId = nextId
            isTranscribing = true
        }

        queueLock.unlock()

        // CRITICAL: Update ProgressManager synchronously on MainActor
        // This ensures the old recording's progress is cleared before the next one starts
        // This fixes the "Transcribing 99%" bug
        await MainActor.run {
            Logger.info("TranscriptionService", "Removing \(recordingId.uuidString.prefix(8)) from queue after completion")
            TranscriptionProgressManager.shared.removeFromQueue(recordingId: recordingId)

            // If there's a next item, activate it immediately
            if let nextId = nextId {
                Logger.info("TranscriptionService", "Next item in queue (\(nextId.uuidString.prefix(8))) is now active")
                TranscriptionProgressManager.shared.setActiveTranscription(recordingId: nextId)
            } else {
                Logger.info("TranscriptionService", "Queue is now empty")
            }
        }
    }

    /// Internal method that performs the actual transcription
    private func performTranscription(audioURL: URL, languageCode: String? = nil, progressCallback: ((Double) -> Void)? = nil) async throws -> TranscriptionResult {
        let settings = SettingsManager.shared

        // Wait for preload to complete
        if let task = preloadTask {
            Logger.info("TranscriptionService", "Waiting for preload to complete...")
            await task.value
            try Task.checkCancellation()
            preloadTask = nil
        }

        // Wait for model loading to complete
        while isLoadingModel {
            try Task.checkCancellation()
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
                        let warmupSuccess = await warmUpModel(whisperKit)
                        isModelReady = true

                        if warmupSuccess {
                            Logger.success("TranscriptionService", "Model warmed up successfully")
                        } else {
                            Logger.warning("TranscriptionService", "Warm-up failed, continuing anyway...")
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
                // Model exists but not ready - wait for warm-up with timeout
                let maxWaitTime = AppConstants.Transcription.modelLoadTimeout
                let waitInterval = AppConstants.Transcription.modelWarmupWaitInterval
                let maxChecks = Int(maxWaitTime * 1_000_000_000 / Double(waitInterval))
                var checkCount = 0

                while !isModelReady && whisperKit != nil && checkCount < maxChecks {
                    try Task.checkCancellation()
                    try? await Task.sleep(nanoseconds: waitInterval)
                    checkCount += 1
                }

                try Task.checkCancellation()

                if !isModelReady {
                    Logger.warning("TranscriptionService", "Timeout waiting for model warm-up, marking ready anyway")
                    isModelReady = true
                }
            }
        }
        
        try Task.checkCancellation()
        
        guard let whisperKit = whisperKit else {
            throw TranscriptionError.initializationFailed
        }
        
        // Double-check: If we think the model is ready but WhisperKit still needs to load,
        // we might need to verify the model is actually initialized
        // Note: WhisperKit doesn't expose a public "isReady" property, so we rely on our flag
        
        // Check if file exists and has content
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            Logger.error("TranscriptionService", "Audio file not found at: \(audioURL.path)")
            throw TranscriptionError.fileNotFound
        }

        // Verify file has valid content (must be at least WAV header size)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? UInt64) ?? 0
        guard fileSize >= AppConstants.Transcription.minValidWAVSize else {
            Logger.error("TranscriptionService", "Audio file too small or empty (\(fileSize) bytes, min \(AppConstants.Transcription.minValidWAVSize)): \(audioURL.lastPathComponent)")
            throw TranscriptionError.fileNotFound
        }

        Logger.info("TranscriptionService", "Starting transcription of: \(audioURL.lastPathComponent) (\(fileSize) bytes)")

        // Get language code from parameter or settings
        let finalLanguageCode = languageCode ?? settings.languageCode(for: settings.audioLanguage)

        // Perform transcription with segment-level timestamps only
        var options = DecodingOptions(wordTimestamps: false)

        if let langCode = finalLanguageCode {
            options.language = langCode
        }

        // Get audio duration for accurate progress calculation
        let asset = AVAsset(url: audioURL)
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)

        // Track start time for timeout and progress
        let startTime = Date()
        let timeoutSeconds: TimeInterval = max(
            totalSeconds * AppConstants.Transcription.timeoutMultiplier,
            AppConstants.Transcription.minTranscriptionTimeout
        )
        
        // Estimate transcription time
        let estimatedTranscriptionTime = totalSeconds * 0.3

        let results = try await whisperKit.transcribe(
            audioPath: audioURL.path,
            decodeOptions: options,
            callback: { progress in
                // Check for cancellation
                if Task.isCancelled {
                    return false // Stop transcription
                }

                // Check for timeout (fail if taking too long)
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed > timeoutSeconds {
                    Logger.error("TranscriptionService", "Transcription timed out after \(Int(elapsed))s")
                    return false // Stop transcription
                }

                // Calculate progress based on elapsed time vs estimated completion time
                if let callback = progressCallback {
                    let progressPercentage = min(max(elapsed / estimatedTranscriptionTime, 0.0), 0.99)

                    Task { @MainActor in
                        if !Task.isCancelled {
                            callback(progressPercentage)
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
            let trimmed = cleanedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

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
        let trimmedFullText = cleanedFullText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
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

        // Report 100% completion after all post-processing is done
        // This ensures progress shows 100% only when transcription is truly complete
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
