//
//  WhisperModelManager.swift
//  Transcription App
//
//  Created by Claude on 12/15/25.
//

import Foundation
import WhisperKit

/// Manages WhisperKit model lifecycle including loading, preloading, and warm-up
/// Handles model initialization, state tracking, and cleanup operations
final class WhisperModelManager {

    // MARK: - Singleton

    static let shared = WhisperModelManager()

    // MARK: - Properties

    private(set) var whisperKit: WhisperKit?
    private var isLoadingModel = false
    private var isModelReady = false
    private var preloadTask: Task<Void, Never>?

    // MARK: - Constants

    private let modelName = "tiny" // Only model we support

    // MARK: - Initialization

    private init() {
        // Clean up any leftover warm-up files from previous sessions
        cleanupOldWarmupFiles()

        // Preload the default model in the background
        Logger.info("WhisperModelManager", "Initializing and starting model preload")
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
            Logger.info("WhisperModelManager", "Model already loading, skipping preload")
            return
        }

        // Only preload if we don't already have the model loaded and ready
        guard whisperKit == nil || !isModelReady else {
            Logger.info("WhisperModelManager", "Model '\(modelName)' already loaded and ready")
            return
        }

        Logger.info("WhisperModelManager", "Preloading model '\(modelName)'...")
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
                    Logger.success("WhisperModelManager", "Model '\(modelName)' preloaded and warmed up successfully")
                } else {
                    Logger.warning("WhisperModelManager", "Model preloaded but warm-up failed - will initialize on first use")
                }
            } else {
                Logger.error("WhisperModelManager", "WhisperKit instance is nil after creation")
                isModelReady = false
            }
        } catch {
            Logger.error("WhisperModelManager", "Failed to preload model: \(error.localizedDescription)")
            isModelReady = false
            // Don't throw - preloading is optional, will load on-demand during transcription
        }
    }

    /// Wait for model to be ready with timeout protection
    /// - Parameter timeout: Maximum time to wait in seconds
    /// - Throws: TranscriptionError if timeout exceeded
    func waitForModelReady(timeout: TimeInterval = AppConstants.Transcription.modelLoadTimeout) async throws {
        let startTime = Date()
        let checkInterval: TimeInterval = 0.2

        while !isModelReadyForTranscription {
            if Date().timeIntervalSince(startTime) > timeout {
                Logger.error("WhisperModelManager", "Model ready timeout exceeded (\(timeout)s)")
                throw TranscriptionError.initializationFailed
            }

            if !isLoadingModel && !isModelReadyForTranscription {
                Logger.warning("WhisperModelManager", "Model not loading and not ready - restarting preload")
                await preloadModel()
            }

            try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            try Task.checkCancellation()
        }

        Logger.success("WhisperModelManager", "Model ready for transcription")
    }

    // MARK: - Private Methods

    /// Warms up WhisperKit model by performing minimal silent audio transcription
    /// This forces full model initialization into Metal buffers
    /// - Parameter whisperKit: The WhisperKit instance to warm up
    /// - Returns: true if warm-up succeeded, false if failed (non-fatal)
    private func warmUpModel(_ whisperKit: WhisperKit) async -> Bool {
        Logger.info("WhisperModelManager", "Warming up model to ensure full initialization...")

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
            Logger.info("WhisperModelManager", "Warm-up transcription completed in \(String(format: "%.2f", warmupDuration))s")
            return true
        } catch {
            Logger.warning("WhisperModelManager", "Warm-up failed: \(error.localizedDescription)")
            return false
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
            Logger.error("WhisperModelManager", "Failed to encode WAV header strings")
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
            Logger.success("WhisperModelManager", "Created warm-up audio file: \(tempURL.lastPathComponent)")
        } catch {
            Logger.error("WhisperModelManager", "Failed to create warm-up audio file: \(error.localizedDescription)")
        }

        return tempURL
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
                Logger.info("WhisperModelManager", "Cleaned up \(warmupFiles.count) old warm-up file(s)")
            }
        } catch {
            Logger.warning("WhisperModelManager", "Failed to clean up old warm-up files: \(error.localizedDescription)")
        }
    }
}
