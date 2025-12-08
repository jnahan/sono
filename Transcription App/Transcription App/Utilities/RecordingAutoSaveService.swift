import Foundation
import SwiftData

/// Service for auto-saving recordings when recording is interrupted or before transcription
struct RecordingAutoSaveService {
    
    /// Auto-save a recording immediately after recording stops, before transcription
    /// - Parameters:
    ///   - fileURL: The URL of the audio file
    ///   - title: The title for the recording (uses filename if empty)
    ///   - modelContext: The SwiftData model context to save to
    /// - Returns: The created Recording, or nil if save failed
    @MainActor
    static func autoSaveRecording(
        fileURL: URL,
        title: String?,
        modelContext: ModelContext
    ) async -> Recording? {
        let recordingTitle = (title?.trimmed.isEmpty == false) 
            ? title!.trimmed 
            : fileURL.deletingPathExtension().lastPathComponent
        
        let recording = Recording(
            title: recordingTitle,
            fileURL: fileURL,
            fullText: "",
            language: "",
            notes: "",
            summary: nil,
            segments: [],
            collection: nil,
            recordedAt: Date(),
            transcriptionStatus: .notStarted,
            failureReason: nil,
            transcriptionStartedAt: nil
        )
        
        modelContext.insert(recording)
        
        do {
            try modelContext.save()
            print("✅ [RecordingAutoSaveService] Recording auto-saved successfully")
            return recording
        } catch {
            print("❌ [RecordingAutoSaveService] Failed to auto-save recording: \(error)")
            return nil
        }
    }
    
    /// Auto-save a recording that was interrupted (e.g., app closed during recording)
    /// - Parameters:
    ///   - fileURL: The URL of the audio file
    ///   - modelContext: The SwiftData model context to save to
    /// - Returns: The created Recording, or nil if save failed or recording already exists
    @MainActor
    static func autoSaveInterruptedRecording(
        fileURL: URL,
        modelContext: ModelContext
    ) async -> Recording? {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("⚠️ [RecordingAutoSaveService] Audio file doesn't exist, skipping auto-save")
            return nil
        }
        
        // Check if this recording already exists in database
        let descriptor = FetchDescriptor<Recording>(
            predicate: #Predicate { recording in
                recording.filePath.contains(fileURL.lastPathComponent)
            }
        )
        
        if let existingRecordings = try? modelContext.fetch(descriptor),
           !existingRecordings.isEmpty {
            print("ℹ️ [RecordingAutoSaveService] Recording already saved, skipping auto-save")
            return nil
        }
        
        print("💾 [RecordingAutoSaveService] Auto-saving interrupted recording")
        
        let recording = Recording(
            title: fileURL.deletingPathExtension().lastPathComponent,
            fileURL: fileURL,
            fullText: "",
            language: "",
            notes: "",
            summary: nil,
            segments: [],
            collection: nil,
            recordedAt: Date(),
            transcriptionStatus: .notStarted,
            failureReason: "Recording was interrupted. The app was closed before transcription could start.",
            transcriptionStartedAt: nil
        )
        
        modelContext.insert(recording)
        
        do {
            try modelContext.save()
            print("✅ [RecordingAutoSaveService] Auto-saved interrupted recording")
            return recording
        } catch {
            print("❌ [RecordingAutoSaveService] Failed to auto-save recording: \(error)")
            return nil
        }
    }
}
