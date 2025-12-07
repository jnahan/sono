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
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            
            let dir = try FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("Recordings", isDirectory: true)
            
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            
            let timestamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
            let url = dir.appendingPathComponent("\(timestamp).m4a")
            fileURL = url
            
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record()
            playStartFeedback()
            isRecording = true
            
            startMetering()
        } catch {
            // Recording start failed - error handled silently
        }
    }
    
    func stop() {
        stopMetering()
        recorder?.stop()
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
                print("⚠️ [Recorder] Audio session interrupted - stopping recording")
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
                print("ℹ️ [Recorder] Audio session interruption ended - can resume")
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
                print("⚠️ [Recorder] Audio device removed - stopping recording")
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
