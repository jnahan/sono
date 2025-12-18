//
//  AppConstants.swift
//  Transcription App
//
//  Created by Jenna Han on 12/3/25.
//

import Foundation

/// App-wide constants
enum AppConstants {

    /// Validation limits for user input
    enum Validation {
        static let maxTitleLength = 50
        static let maxNoteLength = 200
        static let maxCollectionNameLength = 50
    }

    /// LLM configuration constants
    enum LLM {
        static let maxContextLength = 80000
        static let maxSummaryLength = 500
    }
    
    /// Recording constants
    enum Recording {
        /// Maximum recording duration (5 hours in seconds)
        static let maxRecordingDuration: TimeInterval = 5 * 60 * 60 // 18000 seconds
    }

    /// Transcription service constants
    enum Transcription {
        /// Lock timeout for queue operations (seconds)
        static let lockTimeout: TimeInterval = 5.0

        /// Lock retry interval (seconds)
        static let lockRetryInterval: TimeInterval = 0.01

        /// Wait interval between queue checks (seconds)
        static let waitInterval: TimeInterval = 0.2

        /// Model warm-up wait interval (nanoseconds)
        static let modelWarmupWaitInterval: UInt64 = 500_000_000 // 0.5 seconds

        /// Warm-up audio duration (seconds)
        static let warmupAudioDuration: TimeInterval = 0.5

        /// Model loading timeout (seconds)
        static let modelLoadTimeout: TimeInterval = 60.0

        /// Transcription timeout multiplier (times audio duration)
        static let timeoutMultiplier: Double = 5.0

        /// Minimum timeout for short audio (seconds)
        static let minTranscriptionTimeout: TimeInterval = 120.0

        /// Minimum valid WAV file size (bytes) - 44 byte header minimum
        static let minValidWAVSize: UInt64 = 44
    }
    
    /// Notification names
    enum Notification {
        static let recordingSaved = Foundation.Notification.Name("recordingSaved")
    }
}
