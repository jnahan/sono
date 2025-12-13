import SwiftUI

/// Helper for building recording menu actions in confirmation dialogs
struct RecordingMenuActions {
    /// Builds the buttons for a confirmation dialog
    /// This is used as a ViewBuilder closure directly in confirmationDialog
    @ViewBuilder
    static func confirmationDialogButtons(
        recording: Recording,
        onCopy: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        Button("Copy transcription") {
            onCopy()
        }
        
        Button("Share transcription") {
            ShareHelper.shareTranscription(recording.fullText, title: recording.title)
        }
        
        Button("Export audio") {
            if let url = recording.resolvedURL {
                ShareHelper.shareFile(at: url)
            }
        }
        
        Button("Edit") {
            onEdit()
        }
        
        Button("Delete", role: .destructive) {
            onDelete()
        }
        
        Button("Cancel", role: .cancel) {}
    }
}
