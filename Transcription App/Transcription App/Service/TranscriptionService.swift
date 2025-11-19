import Foundation
import WhisperKit

final class TranscriptionService {
    
    static let shared = TranscriptionService()
    
    private init() {}
    
    func transcribe(recording: Recording) async throws {
        let pipe = try await WhisperKit()
        let results = try await pipe.transcribe(audioPath: recording.fileURL.path)
        
        // Save segments directly as Data
        recording.whisperSegmentsData = try? JSONEncoder().encode(results)
        
        // Optional: save full transcription string
        recording.transcription = results.map { $0.text }.joined(separator: " ")
    }
}
