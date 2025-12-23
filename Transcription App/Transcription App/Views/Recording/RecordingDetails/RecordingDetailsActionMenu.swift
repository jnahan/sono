import SwiftUI
import UIKit

enum RecordingDetailsActionMenu {
    static func show(
        recording: Recording,
        onShowCollectionPicker: @escaping () -> Void,
        onShowDeleteConfirm: @escaping () -> Void,
        onShowCopyToast: @escaping () -> Void
    ) {
        ActionSheetManager.shared.show(actions: [
            ActionItem(title: "Copy transcription", icon: "copy", action: {
                UIPasteboard.general.string = recording.fullText
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    onShowCopyToast()
                }
            }),
            ActionItem(title: "Share transcription", icon: "export", action: {
                ShareHelper.shareTranscription(recording.fullText, title: recording.title)
            }),
            ActionItem(title: "Export audio", icon: "waveform", action: {
                if let url = recording.resolvedURL { ShareHelper.shareFile(at: url) }
            }),
            ActionItem(title: "Add to collection", icon: "folder-open", action: {
                onShowCollectionPicker()
            }),
            ActionItem(title: "Delete", icon: "trash", action: {
                onShowDeleteConfirm()
            }, isDestructive: true)
        ])
    }
}
