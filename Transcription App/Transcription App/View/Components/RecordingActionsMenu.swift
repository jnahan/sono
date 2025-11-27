import SwiftUI

/// Reusable menu for recording actions (copy, share, export, edit, delete)
struct RecordingActionsMenu: View {
    // MARK: - Properties
    let recording: Recording
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    // MARK: - Body
    var body: some View {
        Menu {
            Button(action: onCopy) {
                Label("Copy Transcription", systemImage: "doc.on.doc")
            }
            
            Button(action: shareTranscription) {
                Label("Share Transcription", systemImage: "square.and.arrow.up")
            }
            
            Button(action: exportAudio) {
                Label("Export Audio", systemImage: "square.and.arrow.up.fill")
            }
            
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
    }
    
    // MARK: - Actions
    private func shareTranscription() {
        presentActivityViewController(items: [recording.fullText])
    }
    
    private func exportAudio() {
        guard let url = recording.resolvedURL else { return }
        presentActivityViewController(items: [url])
    }
    
    private func presentActivityViewController(items: [Any]) {
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.keyWindow?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}
