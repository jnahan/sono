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
        static let minValidResponseLength = 10
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

        /// Wait validation interval (number of retries before validating state)
        static let waitValidationInterval = 150

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
            static let small: CGFloat = 8
            static let medium: CGFloat = 16
            static let large: CGFloat = 20
            static let extraLarge: CGFloat = 24
            static let xxLarge: CGFloat = 32
        }
        
        /// Icon and image sizes
        enum IconSize {
            static let small: CGFloat = 24
            static let medium: CGFloat = 28
            static let large: CGFloat = 32
        }
        
        /// Corner radius values
        enum CornerRadius {
            static let small: CGFloat = 10
            static let medium: CGFloat = 12
            static let large: CGFloat = 16
            static let pill: CGFloat = 32
        }
        
        /// Animation duration values
        enum AnimationDuration {
            static let short: Double = 0.2
            static let medium: Double = 0.3
            static let toast: Double = 2.0
        }
    }
}
