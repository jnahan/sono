import SwiftUI
import UniformTypeIdentifiers

struct MediaFilePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var onFilePicked: (URL, MediaType) -> Void
    var onCancel: (() -> Void)? = nil
    
    enum MediaType {
        case audio
        case video
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let audioTypes: [UTType] = [
            .audio,
            .mp3,
            .mpeg4Audio,
            UTType(filenameExtension: "m4a") ?? .audio,
            UTType(filenameExtension: "wav") ?? .audio,
            UTType(filenameExtension: "aiff") ?? .audio,
            UTType(filenameExtension: "aif") ?? .audio,
            UTType(filenameExtension: "caf") ?? .audio
        ]
        
        let videoTypes: [UTType] = [
            .movie,
            .video,
            .mpeg4Movie,
            .quickTimeMovie,
            UTType(filenameExtension: "mov") ?? .movie,
            UTType(filenameExtension: "mp4") ?? .movie,
            UTType(filenameExtension: "m4v") ?? .movie
        ]
        
        let supportedTypes = audioTypes + videoTypes
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: MediaFilePicker
        
        init(_ parent: MediaFilePicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access security-scoped resource")
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            let mediaType = determineMediaType(for: url)
            
            do {
                let fileManager = FileManager.default
                let documentsURL = try fileManager.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                ).appendingPathComponent("Recordings", isDirectory: true)
                
                try? fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
                
                let filename = url.lastPathComponent
                let destinationURL = documentsURL.appendingPathComponent(filename)
                
                var finalURL = destinationURL
                if fileManager.fileExists(atPath: destinationURL.path) {
                    let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
                    let name = url.deletingPathExtension().lastPathComponent
                    let ext = url.pathExtension
                    finalURL = documentsURL.appendingPathComponent("\(name)-\(timestamp).\(ext)")
                }
                
                try fileManager.copyItem(at: url, to: finalURL)
                
                print("✅ \(mediaType == .video ? "Video" : "Audio") file imported: \(finalURL.lastPathComponent)")
                
                DispatchQueue.main.async {
                    self.parent.onFilePicked(finalURL, mediaType)
                }
                
            } catch {
                print("Error copying file: \(error)")
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            DispatchQueue.main.async {
                self.parent.onCancel?()
            }
        }
        
        private func determineMediaType(for url: URL) -> MediaType {
            let ext = url.pathExtension.lowercased()
            let videoExtensions = ["mov", "mp4", "m4v", "avi", "mkv", "wmv", "flv"]
            return videoExtensions.contains(ext) ? .video : .audio
        }
    }
}
