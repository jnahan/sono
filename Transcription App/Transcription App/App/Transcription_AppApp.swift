import SwiftUI
import SwiftData

@main
struct Transcription_AppApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Recording.self, RecordingSegment.self, Collection.self])
        let config = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Trigger TranscriptionService initialization to preload the base model
        _ = TranscriptionService.shared
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .modelContainer(sharedModelContainer)
                .environment(\.font, .custom("Inter-Regular", size: 16))
        }
    }
}
