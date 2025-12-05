import Foundation
import AVFoundation
import WhisperKit
import Combine

/// Service for real-time live transcription using WhisperKit
/// Based on WhisperKit's streaming approach: https://github.com/argmaxinc/WhisperKit
@MainActor
class LiveTranscriptionService: ObservableObject {
    // MARK: - Published Properties
    @Published var isTranscribing = false
    @Published var confirmedText = ""
    @Published var hypothesisText = ""
    @Published private(set) var isModelLoaded = false
    @Published private(set) var isLoadingModel = false
    var currentText: String { confirmedText + hypothesisText }
    
    // MARK: - Private Properties
    private var whisperKit: WhisperKit?
    private var audioEngine: AVAudioEngine?
    private var audioBuffer: [Float] = []
    private var transcriptionTask: Task<Void, Never>?
    private var currentModelName: String?
    
    // Configuration
    private let sampleRate: Double = 16000 // WhisperKit expects 16kHz
    private let chunkDuration: TimeInterval = 1.0 // Transcribe every 1 second for faster response
    private let maxBufferDuration: TimeInterval = 12.0 // Keep last 12 seconds
    private let silenceThresholdDb: Float = -50 // Decibel threshold - lower = more sensitive
    private let confirmationDelay: Int = 2 // Confirm text after 2 consistent transcriptions
    private let minSamplesForTranscription: Int = 8000 // 0.5 seconds at 16kHz - start transcribing early
    
    private var lastTranscription = ""
    private var consistentCount = 0
    private var processingTimer: Timer?
    private var recentTexts: [String] = [] // Track recent transcriptions for repetition detection
    
    // MARK: - Initialization
    init() {}
    
    // MARK: - Public Methods
    
    /// Preload the model for faster start
    func preloadModel() async throws {
        let modelName = "tiny"
        
        // Only reload if model changed or not loaded
        guard whisperKit == nil || currentModelName != modelName else { return }
        
        // If model changed, unload the old one
        if currentModelName != modelName {
            whisperKit = nil
            currentModelName = nil
            isModelLoaded = false
        }
        
        isLoadingModel = true
        defer { isLoadingModel = false }
        
        whisperKit = try await WhisperKit(WhisperKitConfig(model: modelName))
        currentModelName = modelName
        isModelLoaded = true
    }
    
    /// Start live transcription
    func startTranscription() async throws {
        guard !isTranscribing else { return }
        
        // Initialize WhisperKit if needed
        if whisperKit == nil {
            try await preloadModel()
        }
        
        // Setup audio session
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
        
        // Setup audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw LiveTranscriptionError.audioEngineSetupFailed
        }
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Create a format for 16kHz mono (what WhisperKit expects)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw LiveTranscriptionError.audioFormatError
        }
        
        // Create converter if needed
        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            Task { @MainActor in
                self?.processAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
            }
        }
        
        // Start the engine
        audioEngine.prepare()
        try audioEngine.start()
        
        // Reset state
        audioBuffer.removeAll()
        confirmedText = ""
        hypothesisText = ""
        lastTranscription = ""
        consistentCount = 0
        isTranscribing = true
        
        // Start periodic transcription
        startPeriodicTranscription()
    }
    
    /// Stop live transcription
    func stopTranscription() {
        isTranscribing = false
        
        // Stop timer
        processingTimer?.invalidate()
        processingTimer = nil
        
        // Cancel any ongoing transcription
        transcriptionTask?.cancel()
        transcriptionTask = nil
        
        // Stop audio engine
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        
        // Finalize any hypothesis text
        if !hypothesisText.isEmpty {
            confirmedText += hypothesisText
            hypothesisText = ""
        }
    }
    
    /// Get the final transcription result
    func getFinalTranscription() -> String {
        return (confirmedText + hypothesisText).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Reset the transcription
    func reset() {
        stopTranscription()
        confirmedText = ""
        hypothesisText = ""
        audioBuffer.removeAll()
        recentTexts.removeAll()
        lastTranscription = ""
        consistentCount = 0
    }
    
    // MARK: - Private Methods
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter?, targetFormat: AVAudioFormat) {
        guard isTranscribing else { return }
        
        var samples: [Float]
        
        if let converter = converter {
            // Convert to 16kHz mono
            let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * sampleRate / buffer.format.sampleRate)
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else { return }
            
            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
            
            if error != nil { return }
            
            guard let channelData = convertedBuffer.floatChannelData?[0] else { return }
            samples = Array(UnsafeBufferPointer(start: channelData, count: Int(convertedBuffer.frameLength)))
        } else {
            // Already in correct format
            guard let channelData = buffer.floatChannelData?[0] else { return }
            samples = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        }
        
        // Add to buffer
        audioBuffer.append(contentsOf: samples)
        
        // Trim buffer if too long (keep last maxBufferDuration seconds)
        let maxSamples = Int(maxBufferDuration * sampleRate)
        if audioBuffer.count > maxSamples {
            audioBuffer.removeFirst(audioBuffer.count - maxSamples)
        }
    }
    
    private func startPeriodicTranscription() {
        // Start first transcription after a short delay (0.5 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            Task { @MainActor [weak self] in
                await self?.transcribeCurrentBuffer()
            }
        }
        
        // Then continue with periodic transcription
        processingTimer = Timer.scheduledTimer(withTimeInterval: chunkDuration, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.transcribeCurrentBuffer()
            }
        }
    }
    
    private func transcribeCurrentBuffer() async {
        guard isTranscribing,
              let whisperKit = whisperKit,
              !audioBuffer.isEmpty else { return }
        
        // Check if there's enough audio
        guard audioBuffer.count >= minSamplesForTranscription else { 
            print("Not enough samples: \(audioBuffer.count) < \(minSamplesForTranscription)")
            return 
        }
        
        // Check if audio has actual content (not silence) using decibel threshold
        let checkSamples = min(audioBuffer.count, minSamplesForTranscription)
        let db = calculateDecibels(audioBuffer.suffix(checkSamples))
        print("Audio level: \(db) dB (threshold: \(silenceThresholdDb))")
        guard db > silenceThresholdDb else { 
            print("Audio below silence threshold, skipping")
            return 
        }
        
        // Get the audio to transcribe (last few seconds for context)
        let contextDuration: TimeInterval = 8.0 // Use last 8 seconds for context
        let contextSamples = Int(contextDuration * sampleRate)
        let samplesToTranscribe = Array(audioBuffer.suffix(min(audioBuffer.count, contextSamples)))
        
        // Cancel previous task if still running
        transcriptionTask?.cancel()
        
        transcriptionTask = Task { [samplesToTranscribe] in
            do {
                // Get language from settings
                let settings = SettingsManager.shared
                let languageCode = settings.languageCode(for: settings.audioLanguage)
                
                // Simpler DecodingOptions - avoid strict thresholds that cause fallback loops
                var options = DecodingOptions(
                    sampleLength: 224,                  // Shorter for faster decoding
                    usePrefillPrompt: false,            // Disable prefill to avoid loops
                    usePrefillCache: false,
                    skipSpecialTokens: true,
                    withoutTimestamps: true,
                    wordTimestamps: false,
                    suppressBlank: true                 // No blank outputs
                )
                
                if let langCode = languageCode {
                    options.language = langCode
                }
                
                let results = try await whisperKit.transcribe(audioArray: samplesToTranscribe, decodeOptions: options)
                
                guard !Task.isCancelled, let result = results.first else { return }
                
                await MainActor.run {
                    self.processTranscriptionResult(result.text)
                }
            } catch is CancellationError {
                // Silently ignore cancellation - this is expected
            } catch {
                print("Live transcription error: \(error)")
            }
        }
    }
    
    private func processTranscriptionResult(_ text: String) {
        let cleanedText = cleanTranscriptionText(text)
        
        // Debug: print what we're getting
        print("Live transcription result: '\(cleanedText)'")
        
        guard !cleanedText.isEmpty else { 
            return  // Don't clear hypothesis on empty - might just be a bad frame
        }
        
        // Track recent texts for loop detection
        recentTexts.append(cleanedText)
        if recentTexts.count > 5 {
            recentTexts.removeFirst()
        }
        
        // Check if we're getting stuck in a loop (same exact text 4+ times)
        if recentTexts.count >= 4 {
            let uniqueRecent = Set(recentTexts.suffix(4))
            if uniqueRecent.count == 1 {
                // Same text 4 times in a row - likely stuck, skip but don't clear
                return
            }
        }
        
        // Simple approach: just show the latest transcription
        // For live transcription, simpler is better
        if cleanedText == lastTranscription {
            consistentCount += 1
            if consistentCount >= confirmationDelay {
                // Confirm the text - move from hypothesis to confirmed
                if !hypothesisText.isEmpty {
                    confirmedText += hypothesisText
                    hypothesisText = ""
                    // Trim buffer to get fresher audio
                    let keepSamples = Int(3.0 * sampleRate)
                    if audioBuffer.count > keepSamples {
                        audioBuffer = Array(audioBuffer.suffix(keepSamples))
                    }
                }
            }
        } else {
            // New transcription - update hypothesis
            consistentCount = 1
            lastTranscription = cleanedText
            
            // Just show the new text as hypothesis (will replace previous hypothesis)
            hypothesisText = (confirmedText.isEmpty ? "" : " ") + cleanedText
        }
    }
    
    private func cleanTranscriptionText(_ text: String) -> String {
        var cleaned = text
        
        // Remove WhisperKit tokens
        let patterns = [
            "<\\|[^|]*\\|>",
            "\\[.*?\\]",
            "\\(.*?\\)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(cleaned.startIndex..., in: cleaned)
                cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
            }
        }
        
        // Remove leading punctuation and whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        while cleaned.hasPrefix("-") || cleaned.hasPrefix("•") {
            cleaned = String(cleaned.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Filter out garbage/hallucination patterns
        if isGarbageOutput(cleaned) {
            return ""
        }
        
        return cleaned
    }
    
    /// Detects garbage output patterns common in Whisper hallucinations
    private func isGarbageOutput(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Empty or very short
        if trimmed.count < 2 {
            return true
        }
        
        // Only filter obvious hallucinations
        let hallucinations = [
            "thank you for watching",
            "thanks for watching", 
            "please subscribe",
            "like and subscribe"
        ]
        
        for phrase in hallucinations {
            if trimmed == phrase || (trimmed.hasPrefix(phrase) && trimmed.count < phrase.count + 10) {
                return true
            }
        }
        
        // Check for extremely repetitive patterns (e.g., "ene ene ene ene ene")
        let words = trimmed.split(separator: " ").map { String($0) }
        if words.count >= 5 {
            let wordCounts = Dictionary(grouping: words, by: { $0 }).mapValues { $0.count }
            if let maxCount = wordCounts.values.max(), maxCount >= words.count - 1 {
                // Almost all words are the same - garbage
                return true
            }
        }
        
        return false
    }
    
    private func calculateRMS(_ samples: ArraySlice<Float>) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(samples.count))
    }
    
    /// Calculate audio level in decibels
    private func calculateDecibels(_ samples: ArraySlice<Float>) -> Float {
        let rms = calculateRMS(samples)
        guard rms > 0 else { return -160 } // Essentially silence
        return 20 * log10(rms)
    }
}

// MARK: - Errors

enum LiveTranscriptionError: LocalizedError {
    case audioEngineSetupFailed
    case audioFormatError
    case transcriptionFailed
    
    var errorDescription: String? {
        switch self {
        case .audioEngineSetupFailed:
            return "Failed to setup audio engine"
        case .audioFormatError:
            return "Failed to create audio format"
        case .transcriptionFailed:
            return "Transcription failed"
        }
    }
}
