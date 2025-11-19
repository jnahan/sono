//
//  ContentView.swift
//  Transcription App
//
//  Created by Jenna Han on 11/19/25.
//

import SwiftUI
import SwiftData
import WhisperKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 20) {
                 Text("My Recordings")
                     .font(.title)
                     .padding(.top)

                 Button("Add Recording") {
                     // For now, just print to test
                     Task {
                         await addRecordingAndTranscribe()
                                    }
                 }
                 .buttonStyle(.borderedProminent)
             }
             .padding()
            List {
                ForEach(items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                    } label: {
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
    private func addRecordingAndTranscribe() async {
        // Locate the audio file
        guard let fileURL = Bundle.main.url(forResource: "jfk", withExtension: "wav") else {
            print("Audio file not found!")
            return
        }
        print("Audio file found at:", fileURL)

        // Transcribe using WhisperKit
        do {
            print("trainscribing audio")
            
            // WhisperKit automatically downloads the recommended model for the device if not specified. You can also select a specific model by passing in the model name:
            

            let pipe = try await WhisperKit(WhisperKitConfig(model: "tiny"))
            let results = try await pipe.transcribe(audioPath: fileURL.path)
            print(results)

        } catch {
            print("Transcription failed:", error)
        }
    }




}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
