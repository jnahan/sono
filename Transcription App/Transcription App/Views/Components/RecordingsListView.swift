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
                    ForEach(recordings) { recording in
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
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.warmGray50)
                        .listRowInsets(EdgeInsets(top: 0, leading: horizontalPadding, bottom: 0, trailing: horizontalPadding))
                        .listRowSpacing(24)
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
