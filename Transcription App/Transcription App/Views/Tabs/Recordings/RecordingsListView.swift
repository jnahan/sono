import SwiftUI
import SwiftData

/// Reusable component for displaying a list of recordings
/// Handles selection mode, navigation, and empty states
struct RecordingsListView: View {
    let recordings: [Recording]
    let viewModel: RecordingListViewModel
    let emptyStateView: AnyView
    let onRecordingTap: (Recording) -> Void
    let onDelete: ((IndexSet) -> Void)?
    let horizontalPadding: CGFloat
    let bottomContentMargin: CGFloat?
    let collections: [Collection]
    let modelContext: ModelContext

    init(
        recordings: [Recording],
        viewModel: RecordingListViewModel,
        emptyStateView: AnyView,
        onRecordingTap: @escaping (Recording) -> Void,
        onDelete: ((IndexSet) -> Void)? = nil,
        horizontalPadding: CGFloat = 20,
        bottomContentMargin: CGFloat? = nil,
        collections: [Collection],
        modelContext: ModelContext
    ) {
        self.recordings = recordings
        self.viewModel = viewModel
        self.emptyStateView = emptyStateView
        self.onRecordingTap = onRecordingTap
        self.onDelete = onDelete
        self.horizontalPadding = horizontalPadding
        self.bottomContentMargin = bottomContentMargin
        self.collections = collections
        self.modelContext = modelContext
    }
    
    var body: some View {
        Group {
            if recordings.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(Array(recordings.enumerated()), id: \.element.id) { index, recording in
                        VStack(spacing: 0) {
                            // 12px spacing above first recording
                            if index == 0 {
                                Spacer()
                                    .frame(height: 12)
                            }
                            
                            Button {
                                if viewModel.isSelectionMode {
                                    // Toggle selection
                                    viewModel.toggleSelection(for: recording.id)
                                } else {
                                    onRecordingTap(recording)
                                }
                            } label: {
                                RecordingRowView(
                                    recording: recording,
                                    onCopy: { viewModel.copyRecording(recording) },
                                    onDelete: { viewModel.deleteRecording(recording) },
                                    collections: collections,
                                    modelContext: modelContext,
                                    isSelectionMode: viewModel.isSelectionMode,
                                    isSelected: viewModel.isSelected(recording.id),
                                    onSelectionToggle: {
                                        viewModel.toggleSelection(for: recording.id)
                                    }
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            // 12px spacing + border after each recording (except last)
                            if index < recordings.count - 1 {
                                Spacer()
                                    .frame(height: viewModel.isSelectionMode ? 20 : 12)
                                
                                HStack(spacing: 0) {
                                    // Add left padding to align divider with recording info (checkbox width 24 + spacing 16 = 40px)
                                    if viewModel.isSelectionMode {
                                        Spacer()
                                            .frame(width: 40)
                                    }
                                    
                                    Rectangle()
                                        .fill(Color.blueGray200)
                                        .frame(height: 1)
                                }
                                
                                Spacer()
                                    .frame(height: 12)
                            } else if viewModel.isSelectionMode {
                                // Extra spacing at bottom for last item in selection mode
                                Spacer()
                                    .frame(height: 8)
                            }
                        }
                        .listRowBackground(Color.blueGray50)
                        .listRowInsets(EdgeInsets(top: 0, leading: horizontalPadding, bottom: 0, trailing: horizontalPadding))
                        .listRowSeparator(.hidden)
                    }
                    .ifLet(onDelete) { view, deleteHandler in
                        view.onDelete(perform: deleteHandler)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .ifLet(bottomContentMargin) { view, margin in
                    view.contentMargins(.bottom, margin, for: .scrollContent)
                }
            }
        }
    }
}
