//
//  RecordingsView.swift
//

import SwiftUI
import SwiftData

struct RecordingsView: View {
    @Environment(\.modelContext) private var modelContext

    @Binding var isRoot: Bool
    @Binding var currentCollectionFilter: CollectionFilter

    let onAddRecording: () -> Void

    @Query(sort: \Recording.recordedAt, order: .reverse) private var recordings: [Recording]
    @Query(sort: \Collection.name) private var collections: [Collection]

    @StateObject private var viewModel = RecordingListViewModel()

    @State private var selectedRecording: Recording?
    @State private var showSettings = false
    @State private var showMoveToCollection = false
    @State private var showDeleteConfirm = false

    // Drawer + filter
    @State private var showCollectionDrawer = false

    @State private var editingCollection: Collection?
    @State private var deletingCollection: Collection?
    @State private var editCollectionName = ""
    @State private var showCreateCollection = false
    @State private var newCollectionName = ""

    // Drawer interaction
    @GestureState private var dragTranslation: CGFloat = 0
    @State private var isDraggingDrawer = false

    private let drawerWidth: CGFloat = 300
    private let edgeOpenZone: CGFloat = 28

    // MARK: - Derived

    private var recordingsFilteredByCollection: [Recording] {
        switch currentCollectionFilter {
        case .all:
            return recordings
        case .unorganized:
            return recordings.filter { $0.collections.isEmpty }
        case .collection(let collection):
            return recordings.filter { rec in
                rec.collections.contains(where: { $0.id == collection.id })
            }
        }
    }

    private var shouldShowFab: Bool {
        isRoot && !viewModel.isSelectionMode
    }

    private var currentFilterTitle: String {
        switch currentCollectionFilter {
        case .all:
            return "All recordings"
        case .unorganized:
            return "Unorganized"
        case .collection(let collection):
            return collection.name
        }
    }

    private var baseOffset: CGFloat { showCollectionDrawer ? drawerWidth : 0 }

    /// Current offset (0...drawerWidth), including interactive drag.
    private var currentOffset: CGFloat {
        let raw = baseOffset + dragTranslation
        return min(max(raw, 0), drawerWidth)
    }

    /// 0...1 used to dim the content slightly while drawer is open/dragging.
    private var openProgress: CGFloat {
        drawerWidth == 0 ? 0 : (currentOffset / drawerWidth)
    }

    var body: some View {
        ZStack(alignment: .leading) {

            // Drawer under content (left)
            CollectionDrawerView(
                collections: collections,
                recordings: recordings,
                selectedFilter: currentCollectionFilter,
                onSelectAll: {
                    currentCollectionFilter = .all
                    applyFiltersToViewModel()
                    closeDrawer()
                },
                onSelectUnorganized: {
                    currentCollectionFilter = .unorganized
                    applyFiltersToViewModel()
                    closeDrawer()
                },
                onSelectCollection: { c in
                    currentCollectionFilter = .collection(c)
                    applyFiltersToViewModel()
                    closeDrawer()
                },
                onRename: { c in
                    editingCollection = c
                    editCollectionName = c.name
                    closeDrawer()
                },
                onDelete: { c in
                    deletingCollection = c
                    closeDrawer()
                },
                onSettingsTap: {
                    showSettings = true
                    closeDrawer()
                },
                onAddCollection: {
                    showCreateCollection = true
                    closeDrawer()
                }
            )
            .frame(width: drawerWidth)
            .ignoresSafeArea(edges: .vertical)

            // Main content pushed right
            ZStack {
                mainContent

                // Tap-to-close overlay ON TOP when open
                if openProgress > 0.01 {
                    Color.black
                        .opacity(0.001)
                        .contentShape(Rectangle())
                        .onTapGesture { closeDrawer() }
                }
            }
            .offset(x: currentOffset)
            .gesture(drawerGesture)
            .transaction { tx in
                if isDraggingDrawer {
                    tx.animation = nil
                }
            }
            .animation(.spring(response: 0.36, dampingFraction: 0.92), value: showCollectionDrawer)
        }

        // Filtering
        .onChange(of: viewModel.searchText) { _, _ in applyFiltersToViewModel() }
        .onChange(of: recordings) { _, _ in applyFiltersToViewModel() }
        .onChange(of: currentCollectionFilter) { _, _ in applyFiltersToViewModel() }

        .onChange(of: viewModel.isSelectionMode) { _, isSelecting in
            if isSelecting { showCollectionDrawer = false }
        }

        .onAppear {
            viewModel.configure(modelContext: modelContext)
            viewModel.recoverIncompleteRecordings(recordings)

            selectedRecording = nil
            applyFiltersToViewModel()
            updateRootState()
        }

        .onChange(of: selectedRecording) { _, _ in updateRootState() }
        .onChange(of: showSettings) { _, _ in updateRootState() }

        // Settings
        .navigationDestination(item: Binding(
            get: { showSettings ? "settings" : nil },
            set: { showSettings = ($0 != nil) }
        )) { _ in
            SettingsView()
        }

        .sheet(isPresented: $showMoveToCollection) {
            CollectionPickerSheet(
                collections: collections,
                selectedCollections: .constant(Set<Collection>()),
                modelContext: modelContext,
                isPresented: $showMoveToCollection,
                recordings: viewModel.selectedRecordingsArray(from: viewModel.filteredRecordings),
                onMassMoveComplete: { viewModel.exitSelectionMode() }
            )
        }

        .sheet(isPresented: $showDeleteConfirm) {
            ConfirmationSheet(
                isPresented: $showDeleteConfirm,
                title: "Delete \(viewModel.selectedRecordings.count) recording\(viewModel.selectedRecordings.count == 1 ? "" : "s")?",
                message: "Are you sure you want to delete \(viewModel.selectedRecordings.count) recording\(viewModel.selectedRecordings.count == 1 ? "" : "s")? This action cannot be undone.",
                confirmButtonText: "Delete",
                cancelButtonText: "Cancel",
                onConfirm: {
                    deleteSelectedRecordings()
                    showDeleteConfirm = false
                    viewModel.exitSelectionMode()
                }
            )
        }

        .sheet(isPresented: Binding(
            get: { editingCollection != nil },
            set: { if !$0 { editingCollection = nil } }
        )) {
            CollectionFormSheet(
                isPresented: Binding(
                    get: { editingCollection != nil },
                    set: { if !$0 { editingCollection = nil } }
                ),
                collectionName: $editCollectionName,
                isEditing: true,
                onSave: {
                    editingCollection?.name = editCollectionName
                    editingCollection = nil
                },
                existingCollections: collections,
                currentCollection: editingCollection
            )
        }

        .sheet(isPresented: $showCreateCollection) {
            CollectionFormSheet(
                isPresented: $showCreateCollection,
                collectionName: $newCollectionName,
                isEditing: false,
                onSave: {
                    if !newCollectionName.isEmpty {
                        let newCollection = Collection(name: newCollectionName)
                        modelContext.insert(newCollection)
                        try? modelContext.save()
                        newCollectionName = ""
                        showCreateCollection = false
                    }
                },
                existingCollections: collections,
                currentCollection: nil
            )
        }

        .sheet(isPresented: Binding(
            get: { deletingCollection != nil },
            set: { if !$0 { deletingCollection = nil } }
        )) {
            if let collection = deletingCollection {
                ConfirmationSheet(
                    isPresented: Binding(
                        get: { deletingCollection != nil },
                        set: { if !$0 { deletingCollection = nil } }
                    ),
                    title: "Delete collection?",
                    message: "Are you sure you want to delete \"\(collection.name)\"?",
                    confirmButtonText: "Delete",
                    cancelButtonText: "Cancel",
                    onConfirm: {
                        modelContext.delete(collection)
                        deletingCollection = nil
                        if case .collection(let selectedCollection) = currentCollectionFilter,
                           selectedCollection.id == collection.id {
                            currentCollectionFilter = .all
                            applyFiltersToViewModel()
                        }
                    }
                )
            }
        }

        .navigationDestination(item: $selectedRecording) { recording in
            RecordingDetailsView(recording: recording)
        }

    }

    // MARK: - Single “ChatGPT-like” Drawer Gesture

    private var drawerGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                // If closed, only start opening if the gesture began near left edge
                if !showCollectionDrawer {
                    guard value.startLocation.x <= edgeOpenZone else { return }
                }
                isDraggingDrawer = true
            }
            .updating($dragTranslation) { value, state, _ in
                // If closed, only allow translation if gesture started in edge zone
                if !showCollectionDrawer && value.startLocation.x > edgeOpenZone {
                    state = 0
                    return
                }
                state = value.translation.width
            }
            .onEnded { value in
                defer { isDraggingDrawer = false }

                // If closed and not an edge swipe, ignore
                if !showCollectionDrawer && value.startLocation.x > edgeOpenZone {
                    return
                }

                let predicted = baseOffset + value.predictedEndTranslation.width
                let shouldOpen = predicted > drawerWidth * 0.5

                if shouldOpen {
                    openDrawer()
                } else {
                    closeDrawer()
                }
            }
    }

    // MARK: - Main Content (your original UI)

    private var mainContent: some View {
        ZStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    CustomTopBar(
                        title: viewModel.isSelectionMode ? "\(viewModel.selectedRecordings.count) selected" : currentFilterTitle,
                        leftIcon: viewModel.isSelectionMode ? nil : "list",
                        rightIcon: viewModel.isSelectionMode ? "x" : "check-circle",
                        onLeftTap: {
                            if !viewModel.isSelectionMode {
                                toggleDrawer()
                            }
                        },
                        onRightTap: {
                            if viewModel.isSelectionMode {
                                viewModel.exitSelectionMode()
                            } else {
                                viewModel.enterSelectionMode()
                            }
                        }
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        if !viewModel.filteredRecordings.isEmpty {
                            SearchBar(text: $viewModel.searchText, placeholder: "Search recordings...")
                                .padding(.horizontal, 20)
                        }
                        recordingsList
                    }
                    .padding(.top, 8)
                }

                if viewModel.isSelectionMode {
                    MassActionButtons(
                        onDelete: { showDeleteConfirm = true },
                        onCopy: { copySelectedRecordings() },
                        onMove: { showMoveToCollection = true },
                        onExport: { exportSelectedRecordings() },
                        isDisabled: viewModel.selectedRecordings.isEmpty,
                        horizontalPadding: 20,
                        bottomPadding: 12,
                        bottomSafeAreaPadding: 8
                    )
                }
            }

            if shouldShowFab {
                if viewModel.filteredRecordings.isEmpty {
                    // Empty state: centered larger button
                    VStack {
                        Spacer()
                        Button {
                            HapticFeedback.medium()
                            onAddRecording()
                        } label: {
                            HStack(spacing: 8) {
                                Image("plus-bold")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.white)
                            }
                            .frame(width: 120, height: 48)
                            .background(Color.black)
                            .cornerRadius(32)
                            .contentShape(Rectangle())
                        }
                        .padding(.bottom, 16)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeOut(duration: 0.12), value: shouldShowFab)
                    .zIndex(900)
                } else {
                    // Has recordings: smaller circular button on right
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                HapticFeedback.medium()
                                onAddRecording()
                            } label: {
                                Image("plus-bold")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.white)
                                    .frame(width: 64, height: 64)
                                    .background(Color.black)
                                    .cornerRadius(32)
                                    .contentShape(Rectangle())
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 16)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeOut(duration: 0.12), value: shouldShowFab)
                    .zIndex(900)
                }
            }
        }
        .overlay(alignment: .top) {
            Group {
                if viewModel.showCopyToast {
                    ToastView(message: "Copied transcription", isPresented: $viewModel.showCopyToast)
                        .padding(.top, 8)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            )
                        )
                }
            }
            .animation(
                viewModel.showCopyToast
                    ? .easeOut(duration: 0.25)
                    : .easeIn(duration: 0.2),
                value: viewModel.showCopyToast
            )
        }
        .background(Color.white.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Helpers

    private func toggleDrawer() {
        showCollectionDrawer ? closeDrawer() : openDrawer()
    }

    private func openDrawer() {
        HapticFeedback.soft()
        withAnimation(.spring(response: 0.36, dampingFraction: 0.92)) {
            showCollectionDrawer = true
        }
    }

    private func closeDrawer() {
        HapticFeedback.soft()
        withAnimation(.spring(response: 0.36, dampingFraction: 0.92)) {
            showCollectionDrawer = false
        }
    }

    private func updateRootState() {
        let pushed =
            (selectedRecording != nil) ||
            showSettings
        isRoot = !pushed
    }

    private func applyFiltersToViewModel() {
        viewModel.updateFilteredRecordings(from: recordingsFilteredByCollection)
    }

    private var recordingsList: some View {
        RecordingsListView(
            recordings: viewModel.filteredRecordings,
            viewModel: viewModel,
            emptyStateView: AnyView(RecordingEmptyStateView()),
            onRecordingTap: { selectedRecording = $0 },
            onDelete: nil,
            horizontalPadding: 20,
            bottomContentMargin: viewModel.isSelectionMode ? 80 : 20,
            collections: collections,
            modelContext: modelContext
        )
    }

    private func deleteSelectedRecordings() {
        viewModel.deleteRecordings(viewModel.selectedRecordingsArray(from: viewModel.filteredRecordings))
    }

    private func copySelectedRecordings() {
        viewModel.copyRecordings(viewModel.selectedRecordingsArray(from: viewModel.filteredRecordings))
        viewModel.exitSelectionMode()
    }

    private func exportSelectedRecordings() {
        viewModel.exportRecordings(viewModel.selectedRecordingsArray(from: viewModel.filteredRecordings))
        withAnimation(.none) {
            viewModel.exitSelectionMode()
        }
    }
}
