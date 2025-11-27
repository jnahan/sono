import SwiftUI
import AVFoundation

/// Reusable row component for displaying a recording with menu actions
struct RecordingRow: View {
    // MARK: - Properties
    let recording: Recording
    @ObservedObject var player: Player
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showMenu = false
    @State private var duration: TimeInterval = 0
    
    // MARK: - Body
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Recording Info
            VStack(alignment: .leading, spacing: 8) {
                // Duration and date
                Text("\(formattedDuration) · \(relativeDate)")
                    .font(.system(size: 14))
                    .foregroundColor(.warmGray500)
                
                // Title
                Text(recording.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.baseBlack)
                    .lineLimit(1)
                
                // Transcript preview
                Text(recording.fullText)
                    .font(.system(size: 14))
                    .foregroundColor(.warmGray600)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Three-dot menu button
            Button {
                showMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20))
                    .foregroundColor(.warmGray600)
                    .rotationEffect(.degrees(90))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .onAppear {
            loadDuration()
        }
        .confirmationDialog("", isPresented: $showMenu, titleVisibility: .hidden) {
            Button("Select") {
                // Handle select action
            }
            
            Button("Copy transcription") {
                onCopy()
            }
            
            Button("Share transcription") {
                shareTranscription()
            }
            
            Button("Export audio") {
                exportAudio()
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
    
    // MARK: - Computed Properties
    private var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        
        if hours > 0 {
            return "\(hours)hr \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            let seconds = Int(duration) % 60
            return "\(seconds)s"
        }
    }
    
    private var relativeDate: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(recording.recordedAt) {
            return "Today"
        } else if calendar.isDateInYesterday(recording.recordedAt) {
            return "Yesterday"
        } else {
            let components = calendar.dateComponents([.day], from: recording.recordedAt, to: now)
            if let days = components.day, days < 7 {
                return "\(days)d ago"
            } else if let days = components.day, days < 30 {
                let weeks = days / 7
                return "\(weeks)w ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: recording.recordedAt)
            }
        }
    }
    
    // MARK: - Actions
    private func loadDuration() {
        guard let url = recording.resolvedURL else { return }
        
        let asset = AVAsset(url: url)
        Task {
            do {
                let duration = try await asset.load(.duration)
                await MainActor.run {
                    self.duration = duration.seconds
                }
            } catch {
                print("Error loading duration: \(error)")
            }
        }
    }
    
    private func shareTranscription() {
        let activityVC = UIActivityViewController(
            activityItems: [recording.fullText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func exportAudio() {
        guard let url = recording.resolvedURL else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}
