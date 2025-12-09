import Combine
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif
import AudioToolbox

/// Handles audio recording with live metering for visualization
final class Recorder: ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var meterLevel: Float = 0
    @Published var meterHistory: [Float] = []
    @Published var wasInterrupted = false // Track if recording was interrupted

    // MARK: - Configuration
    var meterInterval: TimeInterval = 0.03
    var maxHistoryCount: Int = 80

    // MARK: - Private Properties
    private var recorder: AVAudioRecorder?
    private var meterTimer: AnyCancellable?
    private(set) var fileURL: URL?

    // MARK: - Initialization
    init() {
        setupAudioSessionInterruptionHandling()
    }
    
    // MARK: - Public Methods
    func requestPermission(_ done: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { ok in
                DispatchQueue.main.async { done(ok) }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { ok in
                DispatchQueue.main.async { done(ok) }
            }
        }
    }
    
    func start() {
        do {
            let session = AVAudioSession.sharedInstance()
            
            // Deactivate session first to ensure clean state (avoids conflicts with other audio operations)
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            
            // Set category and activate
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            
            let dir = try FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("Recordings", isDirectory: true)
            
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            
            let timestamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
            let url = dir.appendingPathComponent("\(timestamp).m4a")
            
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            recorder = try AVAudioRecorder(url: url, settings: settings)
            
            // Prepare the recorder before starting
            guard let recorder = recorder, recorder.prepareToRecord() else {
                Logger.error("Recorder", "Failed to prepare recorder")
                self.recorder = nil
                return
            }
            
            recorder.isMeteringEnabled = true
            
            // Actually start recording and verify it started
            guard recorder.record() else {
                Logger.error("Recorder", "Failed to start recording - recorder.record() returned false")
                self.recorder = nil
                return
            }
            
            // Only set fileURL and isRecording if recording actually started
            fileURL = url
            isRecording = true
            playStartFeedback()
            startMetering()
            
            Logger.success("Recorder", "Recording started successfully at: \(url.lastPathComponent)")
        } catch {
            Logger.error("Recorder", "Failed to start recording: \(error.localizedDescription)")
            Logger.debug("Recorder", "Error details: \(error)")
            // Reset state on failure
            recorder = nil
            fileURL = nil
            isRecording = false
        }
    }
    
    func stop() {
        stopMetering()
        if let recorder = recorder, recorder.isRecording {
            recorder.stop()

            // Ensure file is properly finalized by deactivating audio session
            // This is crucial for recordings interrupted by backgrounding
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setActive(false, options: .notifyOthersOnDeactivation)
                Logger.success("Recorder", "Audio session deactivated after stop")
            } catch {
                Logger.warning("Recorder", "Failed to deactivate audio session: \(error.localizedDescription)")
            }

            // Verify file exists and has content
            if let fileURL = fileURL {
                let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? UInt64) ?? 0
                Logger.success("Recorder", "Recording stopped. File exists: \(fileExists), Size: \(fileSize) bytes")

                if fileExists && fileSize > 0 {
                    Logger.success("Recorder", "Recording file properly finalized at: \(fileURL.lastPathComponent)")
                } else {
                    Logger.warning("Recorder", "Recording file may be corrupted or empty")
                }
            }
        } else {
            Logger.warning("Recorder", "Stop called but recorder was not recording")
        }
        playStopFeedback()
        isRecording = false
        recorder = nil
    }
    
    // MARK: - Private Methods
    private func startMetering() {
        meterTimer?.cancel()
        
        meterTimer = Timer.publish(every: meterInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let rec = self.recorder, rec.isRecording else { return }
                rec.updateMeters()
                
                let power = rec.averagePower(forChannel: 0)
                self.meterLevel = Self.normalize(power)
                
                self.meterHistory.append(self.meterLevel)
                
                if self.meterHistory.count > self.maxHistoryCount {
                    self.meterHistory.removeFirst(self.meterHistory.count - self.maxHistoryCount)
                }
            }
    }
    
    private func stopMetering() {
        meterTimer?.cancel()
        meterTimer = nil
        meterLevel = 0
        meterHistory.removeAll()
    }
    
    private static func normalize(_ db: Float) -> Float {
        let floor: Float = -60
        if db <= floor { return 0 }
        let clamped = max(min(db, 0), floor)
        return (clamped - floor) / -floor
    }
    
    private func playStartFeedback() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        // Audio sound disabled
    }
    
    private func playStopFeedback() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
        // Audio sound disabled
    }
    
    func reset() {
        stopMetering()
        recorder?.stop()
        isRecording = false
        recorder = nil
        fileURL = nil  // Clear the file URL
        meterLevel = 0
        meterHistory.removeAll()
        wasInterrupted = false
    }

    // MARK: - Audio Session Interruption Handling
    private func setupAudioSessionInterruptionHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )

        // Also observe route changes (e.g., headphones unplugged)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // Interruption began (phone call, alarm, etc.)
            if isRecording {
                Logger.warning("Recorder", "Audio session interrupted - stopping recording")
                wasInterrupted = true
                stop()
            }

        case .ended:
            // Interruption ended
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)

            if options.contains(.shouldResume) {
                Logger.info("Recorder", "Audio session interruption ended - can resume")
                // We don't auto-resume recording, let user decide
            }

        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .oldDeviceUnavailable:
            // Headphones unplugged or audio device removed
            if isRecording {
                Logger.warning("Recorder", "Audio device removed - stopping recording")
                wasInterrupted = true
                stop()
            }

        default:
            break
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
