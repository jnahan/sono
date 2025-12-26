import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Centralized haptic feedback utility for consistent tactile feedback across the app
struct HapticFeedback {

    // MARK: - Notification Haptics

    /// Success notification haptic (3 taps) - use for positive completions
    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// Error notification haptic (3 taps) - use for failures/problems
    static func error() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }

    /// Warning notification haptic (2 taps) - use for destructive actions
    static func warning() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }

    // MARK: - Impact Haptics

    /// Light impact - use for secondary actions
    static func light() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// Medium impact - use for primary actions
    static func medium() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    /// Heavy impact - use for critical/destructive actions
    static func heavy() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
    }

    /// Soft impact - use for subtle feedback
    static func soft() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }

    // MARK: - Selection Haptic

    /// Selection feedback - use for toggles/selections
    static func selection() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}
