import SwiftUI
import UIKit

/// Shared helper for building recording action menus
enum RecordingActionMenuBuilder {
    /// Builds a standard set of actions for a recording using ViewModel methods
    static func buildActions(
        recording: Recording,
        viewModel: RecordingActionsViewModel,
        onCopy: @escaping () -> Void,
        onRetryTranscription: (() -> Void)? = nil,
        onShowCollectionPicker: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> [ActionItem] {
        var actions: [ActionItem] = [
            ActionItem(title: "Copy transcription", icon: "copy", action: onCopy),
            ActionItem(title: "Share transcription", icon: "export", action: {
                viewModel.shareTranscription(recording)
            }),
            ActionItem(title: "Export audio", icon: "waveform", action: {
                viewModel.exportAudio(recording)
            })
        ]

        // Add Re-transcribe option for completed or failed recordings (after Export audio)
        if (recording.status == .completed || recording.status == .failed), let onRetry = onRetryTranscription {
            actions.append(
                ActionItem(title: "Re-transcribe", icon: "arrow-clockwise", action: {
                    HapticFeedback.light()
                    onRetry()
                })
            )
        }

        actions.append(contentsOf: [
            ActionItem(title: "Add to collection", icon: "folder-open", action: onShowCollectionPicker),
            ActionItem(title: "Delete", icon: "trash", action: onDelete, isDestructive: true)
        ])

        return actions
    }
}

/// Action menu for recording details view (three-dots at top)
enum RecordingDetailsActionMenu {
    static func show(
        recording: Recording,
        viewModel: RecordingActionsViewModel,
        onShowCollectionPicker: @escaping () -> Void,
        onShowDeleteConfirm: @escaping () -> Void,
        onShowCopyToast: @escaping () -> Void,
        onRetryTranscription: (() -> Void)? = nil
    ) {
        let actions = RecordingActionMenuBuilder.buildActions(
            recording: recording,
            viewModel: viewModel,
            onCopy: {
                HapticFeedback.success()
                UIPasteboard.general.string = recording.fullText
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    onShowCopyToast()
                }
            },
            onRetryTranscription: onRetryTranscription,
            onShowCollectionPicker: onShowCollectionPicker,
            onDelete: onShowDeleteConfirm
        )

        ActionSheetManager.shared.show(actions: actions)
    }
}
