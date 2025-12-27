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
        // Trigger TranscriptionService initialization to preload Whisper model
        _ = TranscriptionService.shared
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.white
                    .ignoresSafeArea()

                AppRootView()
                    .modelContainer(sharedModelContainer)
                    .environment(\.font, .dmSansRegular(size: 16))
                    .preferredColorScheme(.light) // Force light mode globally
            }
        }
    }
}

