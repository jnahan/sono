import SwiftUI
import SwiftData

@main
struct Transcription_AppApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Recording.self, RecordingSegment.self, Collection.self])
        let config = ModelConfiguration(schema: schema)

        do {
            // SwiftData will automatically handle lightweight migration for new fields with defaults
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // If migration fails, print error details
            print("❌ Migration failed: \(error)")
            print("⚠️ Attempting to create fresh ModelContainer...")

            // Last resort: delete existing store and create new one
            let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")
            let shmURL = URL.applicationSupportDirectory.appending(path: "default.store-shm")
            let walURL = URL.applicationSupportDirectory.appending(path: "default.store-wal")

            for url in [storeURL, shmURL, walURL] {
                if FileManager.default.fileExists(atPath: url.path) {
                    try? FileManager.default.removeItem(at: url)
                    print("🗑️ Removed \(url.lastPathComponent)")
                }
            }

            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create ModelContainer even after cleanup: \(error)")
            }
        }
    }()

    init() {
        // Trigger service initializations to preload models
        _ = TranscriptionService.shared
        _ = LLMService.shared
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .modelContainer(sharedModelContainer)
                .environment(\.font, .custom("Inter-Regular", size: 16))
        }
    }
}
