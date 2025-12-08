# Code Review & Refactoring Plan

## Overview

This document breaks down all features, files, code duplication, and refactoring steps for the transcription app.

---

## Part 1: Feature Breakdown

### Core Features:

1. **Audio Recording** - Record audio with visualizer
2. **Audio Transcription** - Transcribe audio using WhisperKit
3. **Recording Management** - List, search, edit, delete recordings
4. **Collections** - Organize recordings into folders
5. **AI Summary** - Generate summaries using LLM
6. **Ask Sono (Q&A)** - Chat interface for transcription questions
7. **Audio Playback** - Play recordings with segment highlighting
8. **Settings** - Language selection, model selection, display options

---

## Part 2: File-by-File Analysis

### App Entry Point:

- `App/Transcription_AppApp.swift` - Sets up SwiftData container, initializes services

### Models (3 files):

- `Models/Recording.swift` - Main recording entity with transcription status
- `Models/RecordingSegment.swift` - Timestamped transcription segments
- `Models/Collection.swift` - Folder/collection entity

### Services (6 files):

- `Service/TranscriptionService.swift` - WhisperKit transcription (singleton)
- `Service/LLMService.swift` - Local LLM for summaries/Q&A (singleton)
- `Service/SettingsManager.swift` - UserDefaults settings (singleton)
- `Service/Recorder.swift` - Audio recording wrapper
- `Service/Player.swift` - Audio playback wrapper
- `Service/AudioPlayerManager.swift` - Global audio playback manager

### ViewModels (3 files):

- `ViewModels/RecordingFormViewModel.swift` - Recording form logic
- `ViewModels/RecordingDetailsViewModel.swift` - Summary generation logic
- `ViewModels/RecordingListViewModel.swift` - Shared list operations

### Views - Main Navigation:

- `Views/Tabs/MainTabView.swift` - Root TabView with custom tab bar
- `Views/Tabs/NewRecordingSheet.swift` - Recording options sheet

### Views - Recordings List:

- `Views/Tabs/RecordingsList/RecordingsView.swift` - Main recordings list
- `Views/Tabs/RecordingsList/RecordingRowView.swift` - Recording row component
- `Views/Tabs/RecordingsList/RecordingEmptyStateView.swift` - Empty state
- `Views/Tabs/RecordingsList/EditRecordingOverlay.swift` - Edit overlay
- `Views/Tabs/RecordingsList/RecordingActionsMenu.swift` - Actions menu

### Views - Collections:

- `Views/Tabs/Collection/CollectionsView.swift` - Collections list
- `Views/Tabs/Collection/CollectionDetailView.swift` - Collection contents
- `Views/Tabs/Collection/CollectionsRowView.swift` - Collection row
- `Views/Tabs/Collection/CollectionsEmptyStateView.swift` - Empty state

### Views - Recording Details:

- `Views/Recording/RecordingDetails/RecordingDetailsView.swift` - Main detail view (497 lines - TOO LARGE)
- `Views/Recording/RecordingDetails/SummaryView.swift` - Summary tab with ViewModel
- `Views/Recording/RecordingDetails/AskSonoView.swift` - Q&A chat with ViewModel
- `Views/Recording/RecordingDetails/AudioPlayerControls.swift` - Playback controls
- `Views/Recording/RecordingDetails/NoteOverlay.swift` - Notes overlay
- `Views/Recording/RecordingDetails/CustomSlider.swift` - Custom slider component

### Views - Recording Form:

- `Views/Recording/RecordingForm/RecordingFormView.swift` - Create/edit recording form

### Views - Recorder:

- `Views/Recording/Recorder/RecorderView.swift` - Recording interface
- `Views/Recording/Recorder/RecorderControl.swift` - Recording controls
- `Views/Recording/Recorder/RecorderVisualizer.swift` - Audio visualizer

### Views - Settings:

- `Views/Settings/SettingsView.swift` - Settings screen (447 lines - TOO LARGE)

### Views - Components (15 files):

- Various reusable UI components (buttons, toasts, pickers, etc.)

### Utilities (4 files):

- `Utilities/TimeFormatter.swift` - Time formatting
- `Utilities/ValidationHelper.swift` - Form validation
- `Utilities/ShareHelper.swift` - Share sheet helper
- `Utilities/AudioHelper.swift` - Audio file operations

### Extensions (5 files):

- `Extensions/String+Validation.swift` - String helpers
- `Extensions/Color+App.swift` - App colors
- `Extensions/Font+App.swift` - App fonts
- `Extensions/URL+Identifiable.swift` - URL Identifiable conformance
- `Extensions/View+Shadow.swift` - Shadow modifier

### Core:

- `Core/AppConstants.swift` - App-wide constants

---

## Part 3: Code Duplication Identified

### 1. Language Mapping Logic (DUPLICATED)

**Location 1:** `Service/SettingsManager.swift` (lines 70-172)

- `languageCode(for:)` method with 100+ language map

**Location 2:** `Views/Settings/SettingsView.swift` (lines 17-243)

- `localLanguageName(for:)` method with 100+ language map
- `englishLanguageName(for:)` method with reverse map
- `audioLanguages` computed property with language list

**Impact:** ~300 lines duplicated, hard to maintain

### 2. Transcription Truncation Logic (DUPLICATED 3x)

**Location 1:** `ViewModels/RecordingDetailsViewModel.swift` (lines 38-50)
**Location 2:** `Views/Recording/RecordingDetails/SummaryView.swift` (lines 197-209)
**Location 3:** `Views/Recording/RecordingDetails/AskSonoView.swift` (lines 301-313)

**Code:**

```swift
let maxInputLength = 3000
let transcriptionText: String

if recording.fullText.count > maxInputLength {
    let beginningLength = Int(Double(maxInputLength) * 0.6)
    let endLength = maxInputLength - beginningLength - 50
    let beginning = String(recording.fullText.prefix(beginningLength))
    let end = String(recording.fullText.suffix(endLength))
    transcriptionText = "\(beginning)\n\n[...]\n\n\(end)"
} else {
    transcriptionText = recording.fullText
}
```

**Impact:** Same logic repeated 3 times, ~12 lines each = 36 lines duplicated

### 3. Auto-Save Recording Logic (DUPLICATED)

**Location 1:** `ViewModels/RecordingFormViewModel.swift` (lines 267-300)

- `autoSaveRecording()` method

**Location 2:** `Views/Recording/Recorder/RecorderView.swift` (lines 109-156)

- `autoSaveRecordingIfNeeded()` method

**Impact:** Similar logic for creating Recording with `.notStarted` status, ~30 lines duplicated

### 4. Duplicate Extension Files

- `Extensions/URL+Identifiable.swift` - Correct file
- `Extensions/URL+Identifier.swift` - Duplicate (typo in name)

**Impact:** Confusion, potential build issues

---

## Part 4: Refactoring Plan

### Phase 1: Remove Duplicate Files

**Step 1.1:** Delete duplicate extension

- Delete `Extensions/URL+Identifier.swift`
- Verify `URL+Identifiable.swift` exists and is in project
- Build and test

**Risk:** Low - just removing duplicate

---

### Phase 2: Extract Language Mapping Utility

**Step 2.1:** Create `Utilities/LanguageMapper.swift`

- Create struct with static methods
- Move language code map from `SettingsManager`
- Move localized name map from `SettingsView`
- Move reverse map logic from `SettingsView`
- Move language list from `SettingsView`
- Add methods:
  - `languageCode(for:) -> String?`
  - `localizedName(for:) -> String`
  - `englishName(for:) -> String`
  - `allLanguages: [String]`

**Step 2.2:** Update `SettingsManager.swift`

- Replace `languageCode(for:)` implementation
- Call `LanguageMapper.languageCode(for:)`

**Step 2.3:** Update `SettingsView.swift`

- Remove `localLanguageName(for:)` method
- Remove `englishLanguageName(for:)` method
- Update `audioLanguages` to use `LanguageMapper.allLanguages`
- Update bindings to use `LanguageMapper.localizedName(for:)` and `LanguageMapper.englishName(for:)`

**Step 2.4:** Add to Xcode project

- Add `LanguageMapper.swift` to project.pbxproj
- Add to PBXBuildFile section
- Add to PBXFileReference section
- Add to Utilities PBXGroup
- Add to PBXSourcesBuildPhase

**Step 2.5:** Test

- Build project
- Test language selection in settings
- Verify language codes work for transcription

**Risk:** Medium - affects settings functionality

---

### Phase 3: Extract Transcription Truncation Utility

**Step 3.1:** Create `Utilities/TranscriptionTruncator.swift`

- Create struct with static method
- Move truncation logic into `truncate(_:maxLength:) -> String`
- Default `maxLength = 3000`

**Step 3.2:** Update `RecordingDetailsViewModel.swift`

- Replace truncation code with `TranscriptionTruncator.truncate(recording.fullText)`

**Step 3.3:** Update `SummaryView.swift`

- In `SummaryViewModel.generateSummary()`, replace truncation code

**Step 3.4:** Update `AskSonoView.swift`

- In `AskSonoViewModel.sendPrompt()`, replace truncation code

**Step 3.5:** Add to Xcode project

- Add `TranscriptionTruncator.swift` to project.pbxproj (same sections as above)

**Step 3.6:** Test

- Build project
- Test summary generation
- Test Ask Sono Q&A
- Verify truncation works correctly

**Risk:** Low - isolated utility, easy to test

---

### Phase 4: Extract Auto-Save Service

**Step 4.1:** Create `Utilities/RecordingAutoSaveService.swift`

- Create struct with static methods
- Method 1: `autoSaveRecording(fileURL:title:modelContext:) async -> Recording?`
  - For normal auto-save before transcription
  - No failure reason
- Method 2: `autoSaveInterruptedRecording(fileURL:modelContext:) async -> Recording?`
  - For interrupted recordings
  - Sets failure reason
  - Checks if already exists

**Step 4.2:** Update `RecordingFormViewModel.swift`

- Replace `autoSaveRecording()` implementation
- Call `RecordingAutoSaveService.autoSaveRecording(...)`

**Step 4.3:** Update `RecorderView.swift`

- Replace `autoSaveRecordingIfNeeded()` implementation
- Call `RecordingAutoSaveService.autoSaveInterruptedRecording(...)`

**Step 4.4:** Add to Xcode project

- Add `RecordingAutoSaveService.swift` to project.pbxproj

**Step 4.5:** Test

- Build project
- Test recording and saving
- Test app interruption during recording
- Verify auto-save works

**Risk:** Medium - affects recording persistence

---

### Phase 5: Split Large Views

**Step 5.1:** Split `RecordingDetailsView.swift` (497 lines)

- Extract transcript view → `RecordingDetailsTranscriptView.swift`
- Extract header → `RecordingDetailsHeaderView.swift`
- Extract warning toast → `RecordingDetailsWarningView.swift`
- Keep main view as coordinator

**Step 5.2:** Split `SettingsView.swift` (447 lines)

- Extract language picker → `LanguagePickerView.swift`
- Extract settings rows → `SettingsSectionView.swift`

**Risk:** Medium - requires careful state management

---

### Phase 6: Consolidate ViewModels

**Step 6.1:** Merge `SummaryView.SummaryViewModel` into `RecordingDetailsViewModel`

- Move summary generation logic
- Remove separate ViewModel file
- Update `SummaryView` to use `RecordingDetailsViewModel`

**Step 6.2:** Consider merging `AskSonoView.AskSonoViewModel`

- Evaluate if it makes sense to merge
- Keep separate if logic is too different

**Risk:** Medium - affects view/viewmodel relationships

---

### Phase 7: Service Refactoring

**Step 7.1:** Refactor `TranscriptionService`

- Consolidate model loading logic
- Extract warm-up logic to separate method
- Improve error handling

**Step 7.2:** Refactor `LLMService`

- Consolidate prompt formatting
- Extract model loading/reset logic
- Improve error handling

**Risk:** High - core functionality, test thoroughly

---

## Part 5: Implementation Order (Safest to Riskiest)

1. **Phase 1** - Remove duplicate files (Lowest risk)
2. **Phase 3** - Extract truncation utility (Low risk, isolated)
3. **Phase 2** - Extract language mapper (Medium risk, affects settings)
4. **Phase 4** - Extract auto-save service (Medium risk, affects persistence)
5. **Phase 5** - Split large views (Medium risk, UI changes)
6. **Phase 6** - Consolidate ViewModels (Medium risk, architecture changes)
7. **Phase 7** - Service refactoring (Highest risk, core functionality)

---

## Part 6: Testing Checklist (After Each Phase)

- [ ] Project builds without errors
- [ ] No runtime crashes
- [ ] Feature still works as before
- [ ] No regressions in related features
- [ ] Xcode project file is correct (files added/removed properly)

---

## Part 7: Critical Notes

1. Always add new files to `project.pbxproj` in 4 places:

   - PBXBuildFile section
   - PBXFileReference section
   - Appropriate PBXGroup section
   - PBXSourcesBuildPhase section

2. Test after each phase before moving to next

3. Keep backups or use git commits between phases

4. If something breaks, revert that phase and investigate

5. The duplicate `URL+Identifier.swift` file should be deleted first

---

## Part 8: File Dependencies Map

### Critical Dependencies:

- `RecordingDetailsView` → `SummaryView`, `AskSonoView`, `AudioPlayerControls`
- `RecordingFormView` → `RecordingFormViewModel`
- `SettingsView` → `SettingsManager`
- `TranscriptionService` → `SettingsManager` (for model selection)
- `LLMService` → Used by `SummaryView`, `AskSonoView`, `RecordingDetailsViewModel`

### Data Flow:

- Models → ViewModels → Views
- Services → ViewModels → Views
- Settings → Services (TranscriptionService, LLMService)

---

This plan breaks down each refactoring step. Follow phases in order and test after each one.
