import UIKit
import Foundation

/// Utility for sharing content and files
struct ShareHelper {
    
    /// Share text content using the system share sheet
    /// - Parameter text: The text to share
    static func shareText(_ text: String) {
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        
        presentActivityController(activityVC)
    }
    
    /// Sanitizes a string to be used as a filename
    /// - Parameter title: The title to sanitize
    /// - Returns: A sanitized filename-safe string
    private static func sanitizeFileName(_ title: String) -> String {
        return title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "*", with: "-")
            .replacingOccurrences(of: "?", with: "-")
            .replacingOccurrences(of: "\"", with: "-")
            .replacingOccurrences(of: "<", with: "-")
            .replacingOccurrences(of: ">", with: "-")
            .replacingOccurrences(of: "|", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Creates a .txt file from transcription text with the recording title as filename
    /// - Parameters:
    ///   - text: The transcription text
    ///   - title: The recording title to use as the filename
    /// - Returns: The URL of the created file, or nil if creation failed
    static func createTranscriptionFile(_ text: String, title: String) -> URL? {
        let sanitizedTitle = sanitizeFileName(title)
        let fileName = sanitizedTitle.isEmpty ? "Transcription" : sanitizedTitle
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(fileName).txt")
        
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }
    
    /// Share a transcription as a .txt file with the recording title as filename
    /// - Parameters:
    ///   - text: The transcription text to share
    ///   - title: The recording title to use as the filename
    static func shareTranscription(_ text: String, title: String) {
        if let fileURL = createTranscriptionFile(text, title: title) {
            shareFile(at: fileURL)
        } else {
            // Fallback to text sharing if file creation fails
            shareText(text)
        }
    }
    
    /// Share a file using the system share sheet
    /// - Parameter url: The URL of the file to share
    static func shareFile(at url: URL) {
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        presentActivityController(activityVC)
    }
    
    /// Share multiple items (text, files, etc.) using the system share sheet
    /// - Parameter items: The items to share
    static func shareItems(_ items: [Any]) {
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        presentActivityController(activityVC)
    }
    
    // MARK: - Private Helpers
    
    private static func presentActivityController(_ activityVC: UIActivityViewController) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            return
        }
        
        rootVC.present(activityVC, animated: true)
    }
}
