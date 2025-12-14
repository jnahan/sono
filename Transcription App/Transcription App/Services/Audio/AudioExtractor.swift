import Foundation
import AVFoundation

/// Utility for extracting audio from video files
/// Converts video files to audio format compatible with WhisperKit transcription
class AudioExtractor {

    /// Extracts audio from a video file and saves it as M4A format
    /// - Parameter videoURL: URL of the video file
    /// - Returns: URL of the extracted audio file
    /// - Throws: AudioExtractionError if extraction fails
    static func extractAudio(from videoURL: URL) async throws -> URL {
        Logger.info("AudioExtractor", "Extracting audio from: \(videoURL.lastPathComponent)")

        // Verify the video file exists
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            throw AudioExtractionError.fileNotFound
        }

        // Create asset from video file
        let asset = AVAsset(url: videoURL)

        // Verify the asset has audio tracks
        guard try await asset.loadTracks(withMediaType: .audio).count > 0 else {
            throw AudioExtractionError.noAudioTrack
        }

        // Create output URL for the audio file
        let outputURL = try createOutputURL(for: videoURL)

        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioExtractionError.exportSessionFailed
        }

        // Configure export session
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        // Export the audio
        await exportSession.export()

        // Check export status
        switch exportSession.status {
        case .completed:
            // Verify the audio file was actually created and has content
            guard FileManager.default.fileExists(atPath: outputURL.path) else {
                Logger.error("AudioExtractor", "Export completed but file doesn't exist at: \(outputURL.path)")
                throw AudioExtractionError.exportFailed("Output file was not created")
            }

            let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? UInt64) ?? 0
            guard fileSize > 0 else {
                Logger.error("AudioExtractor", "Export completed but file is empty (0 bytes)")
                throw AudioExtractionError.exportFailed("Output file is empty")
            }

            Logger.success("AudioExtractor", "Audio extracted successfully: \(outputURL.lastPathComponent) (\(fileSize) bytes)")
            return outputURL

        case .failed:
            let error = exportSession.error?.localizedDescription ?? "Unknown error"
            Logger.error("AudioExtractor", "Export failed: \(error)")
            throw AudioExtractionError.exportFailed(error)

        case .cancelled:
            Logger.warning("AudioExtractor", "Export was cancelled")
            throw AudioExtractionError.exportCancelled

        default:
            throw AudioExtractionError.exportFailed("Unknown export status: \(exportSession.status.rawValue)")
        }
    }

    /// Creates an output URL for the extracted audio file
    /// - Parameter videoURL: The source video URL
    /// - Returns: URL for the output audio file in the Recordings directory
    private static func createOutputURL(for videoURL: URL) throws -> URL {
        let fileManager = FileManager.default

        // Get the Recordings directory
        let recordingsDir = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("Recordings", isDirectory: true)

        try fileManager.createDirectory(at: recordingsDir, withIntermediateDirectories: true)

        // Create unique filename based on original video name
        let videoName = videoURL.deletingPathExtension().lastPathComponent
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let audioFileName = "\(videoName)-audio-\(timestamp).m4a"

        return recordingsDir.appendingPathComponent(audioFileName)
    }

    /// Checks if a file is a video file based on its extension
    /// - Parameter url: URL of the file to check
    /// - Returns: True if the file is a video file
    static func isVideoFile(_ url: URL) -> Bool {
        let videoExtensions = ["mov", "mp4", "m4v", "avi", "mkv", "wmv", "flv"]
        let ext = url.pathExtension.lowercased()
        return videoExtensions.contains(ext)
    }
}

// MARK: - Errors

enum AudioExtractionError: LocalizedError {
    case fileNotFound
    case noAudioTrack
    case exportSessionFailed
    case exportFailed(String)
    case exportCancelled

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Video file not found"
        case .noAudioTrack:
            return "Video file does not contain an audio track"
        case .exportSessionFailed:
            return "Failed to create audio export session"
        case .exportFailed(let details):
            return "Audio extraction failed: \(details)"
        case .exportCancelled:
            return "Audio extraction was cancelled"
        }
    }
}
