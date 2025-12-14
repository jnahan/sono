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
    
    init(
        recordings: [Recording],
        viewModel: RecordingListViewModel,
        emptyStateView: AnyView,
        onRecordingTap: @escaping (Recording) -> Void,
        onDelete: ((IndexSet) -> Void)? = nil,
        horizontalPadding: CGFloat = AppConstants.UI.Spacing.large,
        bottomContentMargin: CGFloat? = nil
    ) {
        self.recordings = recordings
        self.viewModel = viewModel
        self.emptyStateView = emptyStateView
        self.onRecordingTap = onRecordingTap
        self.onDelete = onDelete
        self.horizontalPadding = horizontalPadding
        self.bottomContentMargin = bottomContentMargin
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
                                    onEdit: { viewModel.editRecording(recording) },
                                    onDelete: { viewModel.deleteRecording(recording) },
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
                                
                                Rectangle()
                                    .fill(Color.warmGray200)
                                    .frame(height: 1)
                                
                                Spacer()
                                    .frame(height: 12)
                            } else if viewModel.isSelectionMode {
                                // Extra spacing at bottom for last item in selection mode
                                Spacer()
                                    .frame(height: 8)
                            }
                        }
                        .listRowBackground(Color.warmGray50)
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

// MARK: - View Extension for Conditional Modifiers

private extension View {
    @ViewBuilder
    func `ifLet`<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}
