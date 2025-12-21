import Foundation
import SwiftData

/// Represents the status of a recording's transcription
enum TranscriptionStatus: String, Codable {
    case notStarted     // Recording saved but transcription hasn't started
    case inProgress     // Transcription is currently running
    case completed      // Transcription completed successfully
    case failed         // Transcription failed or was interrupted
}

/// Represents a single audio recording with its transcription
/// Contains the audio file, full transcribed text, segments with timestamps,
/// and optional folder organization
@Model
class Recording {
    // MARK: - Identifiers
    @Attribute(.unique) var id: UUID
    
    // MARK: - Basic Info
    var title: String
    var recordedAt: Date
    var language: String
    
    // MARK: - Audio File
    var filePath: String
    
    // MARK: - Transcription
    var fullText: String // Complete transcription
    @Relationship(deleteRule: .cascade)
    var segments: [RecordingSegment] = [] // Timestamped segments
    var transcriptionStatus: String = TranscriptionStatus.completed.rawValue // Default to completed for existing recordings
    var failureReason: String? = nil // Description of why transcription failed
    var transcriptionStartedAt: Date? = nil // When transcription began
    
    // MARK: - AI Summary
    var summary: String?
    
    // MARK: - Organization
    @Relationship(inverse: \Collection.recordings)
    var collection: Collection?
    
    // MARK: - Computed Properties
    var status: TranscriptionStatus {
        get { TranscriptionStatus(rawValue: transcriptionStatus) ?? .notStarted }
        set { transcriptionStatus = newValue.rawValue }
    }

    var resolvedURL: URL? {
        guard let appSupportDir = try? FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
            return nil
        }
        
        // Try to resolve as relative path first (new recordings)
        let relativeURL = appSupportDir.appendingPathComponent(filePath)
        if FileManager.default.fileExists(atPath: relativeURL.path) {
            return relativeURL
        }
        
        // Fallback: Handle old absolute paths by extracting filename and looking in Recordings folder
        let filename = URL(fileURLWithPath: filePath).lastPathComponent
        let fallbackURL = appSupportDir
            .appendingPathComponent("Recordings")
            .appendingPathComponent(filename)
        
        if FileManager.default.fileExists(atPath: fallbackURL.path) {
            return fallbackURL
        }
        
        // Last resort: try the original absolute path (will fail for old recordings after rebuild)
        let absoluteURL = URL(fileURLWithPath: filePath)
        if FileManager.default.fileExists(atPath: absoluteURL.path) {
            return absoluteURL
        }
        
        return nil
    }
    
    init(
        title: String,
        fileURL: URL,  // Only accept URL, no need for filePath parameter
        fullText: String,
        language: String,
        summary: String? = nil,
        segments: [RecordingSegment] = [],
        collection: Collection? = nil,
        recordedAt: Date,
        transcriptionStatus: TranscriptionStatus = .completed,
        failureReason: String? = nil,
        transcriptionStartedAt: Date? = nil
    ) {
        self.id = UUID()
        self.title = title

        // Store relative path from Application Support directory
        if let appSupportDir = try? FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false),
           fileURL.path.hasPrefix(appSupportDir.path) {
            // Extract relative path
            self.filePath = String(fileURL.path.dropFirst(appSupportDir.path.count + 1))
        } else {
            // Fallback to absolute path if we can't determine relative path
            self.filePath = fileURL.path
        }

        self.fullText = fullText
        self.language = language
        self.summary = summary
        self.segments = segments
        self.collection = collection
        self.recordedAt = recordedAt
        self.transcriptionStatus = transcriptionStatus.rawValue
        self.failureReason = failureReason
        self.transcriptionStartedAt = transcriptionStartedAt
    }
}
