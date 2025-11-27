import Foundation
import SwiftData

/// Represents a time-stamped segment of a recording's transcription
/// Each segment contains start/end times and the transcribed text for that time range
@Model
class RecordingSegment {
    // MARK: - Identifiers
    @Attribute(.unique) var id: UUID
    
    // MARK: - Timestamp
    var start: Double // Start time in seconds
    var end: Double // End time in seconds
    
    // MARK: - Content
    var text: String // Transcribed text for this segment
    
    // MARK: - Relationships
    @Relationship(inverse: \Recording.segments)
    var recording: Recording? // Parent recording

    init(start: Double, end: Double, text: String) {
        self.id = UUID()
        self.start = start
        self.end = end
        self.text = text
    }
}
