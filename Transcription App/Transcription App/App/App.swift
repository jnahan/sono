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
        // Trigger service initializations to preload models
        _ = TranscriptionService.shared
        _ = LLMService.shared
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.warmGray50
                    .ignoresSafeArea()

                MainTabView()
                    .modelContainer(sharedModelContainer)
                    .environment(\.font, .dmSansRegular(size: 16))
            }
        }
    }
}

