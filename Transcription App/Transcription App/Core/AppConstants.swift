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
    }
    
    /// Notification names
    enum Notification {
        static let recordingSaved = Foundation.Notification.Name("recordingSaved")
    }
    
    /// UI spacing and layout constants
    enum UI {
        /// Standard spacing values
        enum Spacing {
            static let medium: CGFloat = 16
            static let large: CGFloat = 20
        }
    }
}
