# Edge Case Handling Implementation Plan

## Overview
Implement robust error handling, state management, and user experience improvements across recording, transcription, file management, and UI components.

---

## Phase 1: Core Infrastructure & Safety

### 1.1 Storage Management Service
**New file:** `Service/StorageManager.swift`

Implement:
- Check available storage before recording
- Get disk space remaining
- Calculate recording size estimates
- Minimum space threshold (500MB)
- Alert user when storage low

**Integration points:**
- Call before starting recording in `Recorder.swift`
- Show warning sheet in `RecordingView.swift`

### 1.2 App State Persistence
**New file:** `Service/AppStateManager.swift`

Save and restore:
- In-progress recording URL
- Transcription state (audio URL, progress)
- Unsaved form data
- Last active recording ID

**Integration:**
- Save state in `Transcription_AppApp.swift` scene phase changes
- Restore on app launch
- Handle crash recovery

### 1.3 Audio File Lifecycle Management
**Modify:** `Models/Recording.swift`

Add methods:
- `cleanupAudioFile()` - delete file from disk
- `validateFileExists()` - check if file still exists
- `fileSize` - computed property

**Modify:** SwiftData model deletion
- Override deletion to clean up audio files
- Handle cascading deletes for folders

---

## Phase 2: Recording Enhancements

### 2.1 Audio Session Management
**Modify:** `Service/Recorder.swift`

Implement:
- Background audio mode capability
- Handle audio interruptions (phone calls, alarms)
- Auto-pause on interruption
- Resume option after interruption
- Audio route change handling (AirPods disconnect)

Add new states:
```swift
enum RecordingState {
    case idle
    case recording
    case paused
    case interrupted
}
```

### 2.2 Recording Limits & Warnings
**Modify:** `Views/Recording/Recorder/RecorderControl.swift`

Add:
- Warning at 30 minutes (transcription may be slow)
- Warning at 60 minutes (large file size)
- Maximum duration limit (2 hours)
- Show file size estimate in real-time
- Storage check before starting

### 2.3 Recording State Persistence
**Modify:** `Service/Recorder.swift`

- Save partial recording if app killed
- Auto-save every 30 seconds to temporary location
- Recover partial recordings on relaunch
- Show recovery sheet on app restart

### 2.4 Audio Playback Conflicts
**Modify:** `Service/Player.swift`

- Singleton pattern to prevent multiple players
- Auto-stop playback when recording starts
- Handle audio session conflicts gracefully

---

## Phase 3: Transcription Robustness

### 3.1 Immediate Audio Save
**Modify:** `Views/Recording/RecordingForm/RecordingFormView.swift`

- Save audio file to database BEFORE transcription
- Create Recording object with empty transcription
- Update transcription when complete
- User can navigate away during transcription

### 3.2 Transcription Progress & Cancellation
**Modify:** `Service/TranscriptionService.swift`

Add:
- Progress callback (0-100%)
- Estimated time remaining
- Cancel operation support
- Keep device awake during transcription

**Modify:** `Views/Recording/RecordingForm/RecordingFormView.swift`

Add:
- Progress bar instead of animation
- "Cancel" button option
- Time elapsed/estimated display

### 3.3 Transcription Error Handling
**Modify:** `Service/TranscriptionService.swift`

Handle:
- Silent audio detection
- Poor quality audio warning
- Out of memory errors
- Timeout errors (>10 minutes)
- Unsupported format errors

Add retry logic:
- Automatic retry on failure (up to 3 times)
- Manual retry button
- Save audio even if transcription fails

### 3.4 Background Transcription
**New file:** `Service/TranscriptionQueue.swift`

Implement:
- Queue multiple transcriptions
- Process one at a time
- Show queue status in UI
- Persist queue across app restarts
- Limit to 3 concurrent operations

---

## Phase 4: File Management & Data Integrity

### 4.1 Missing File Handling
**Modify:** All views that play audio

Add checks:
- Validate file exists before playing
- Show "File not found" alert
- Offer to delete recording if file missing
- Handle gracefully without crashing

**Create:** `Views/Components/MissingFileAlert.swift`

### 4.2 File Cleanup & Orphan Prevention
**Modify:** Recording deletion logic

Implement:
- Delete audio file when deleting Recording
- Scan for orphaned files on app launch
- Offer to clean up orphaned files
- Add "Storage Used" display in settings

**New file:** `Service/FileCleanupService.swift`

### 4.3 Duplicate Name Handling
**Modify:** `Views/Recording/RecordingForm/RecordingFormView.swift`

- Check for duplicate titles
- Auto-append number (Recording 1, Recording 2)
- Show warning if duplicate exists
- Validate on save

### 4.4 Folder Deletion Handling
**Modify:** Folder deletion logic

Options when deleting folder with recordings:
- Move recordings to "Uncategorized"
- Delete all recordings in folder
- Show confirmation sheet with count

---

## Phase 5: UI/UX Improvements

### 5.1 Form Validation Enhancements
**Modify:** `Views/Recording/RecordingForm/RecordingFormView.swift`

- Trim whitespace from titles
- Prevent titles with only spaces
- Character limit enforcement (already done)
- Show character count

### 5.2 Double-Tap Prevention
**Modify:** All save/submit buttons

Add:
- Disable button immediately on tap
- Show loading state
- Re-enable only on error
- Use @State flag `isSaving`

### 5.3 Exit Confirmation During Transcription
**Modify:** `Views/Recording/RecordingForm/RecordingFormView.swift`

- Prevent dismiss gesture during transcription
- Show strong warning if user tries to exit
- Explain consequences clearly

### 5.4 Memory Management for Large Files
**Modify:** `Service/Player.swift` and transcript display

- Stream large audio files instead of loading fully
- Paginate very long transcripts (>5000 words)
- Lazy load waveform data
- Release memory when view disappears

### 5.5 Low Power Mode Detection
**New file:** `Service/SystemStatusMonitor.swift`

- Detect low power mode
- Warn before starting transcription
- Offer to skip transcription, save audio only
- Show estimated battery impact

---

## Phase 6: Polish & Accessibility

### 6.1 Dark Mode Audit
**Review all views:**

- Test all colors in dark mode
- Ensure contrast ratios meet WCAG
- Update custom colors if needed
- Test with dynamic type sizes

### 6.2 VoiceOver Support
**Add accessibility labels to:**

- All icon buttons (no text labels)
- Recording controls
- Playback controls
- Form fields
- State indicators

### 6.3 Loading States & Empty States
**Create components:**

- Generic loading view with message
- Empty state for failed transcription
- Retry buttons with explanations
- Better error messages (user-friendly)

### 6.4 Settings Screen Additions
**Modify:** Settings view

Add options:
- Storage used display
- Clear cache option
- Transcription quality setting
- Auto-delete old recordings
- Recording quality settings

---

## Implementation Order (by priority)

### Priority 1 (Critical - Must Fix):
1. **Phase 3.1:** Save audio before transcription
2. **Phase 1.1:** Storage checks
3. **Phase 2.4:** Stop playback when recording
4. **Phase 4.1:** Handle missing files
5. **Phase 4.2:** Delete audio files with recordings

### Priority 2 (Important - Should Fix):
6. **Phase 2.1:** Handle interruptions
7. **Phase 2.3:** Background recording
8. **Phase 3.2:** Transcription progress
9. **Phase 5.2:** Double-tap prevention
10. **Phase 5.1:** Title validation (whitespace)

### Priority 3 (Nice to Have):
11. **Phase 4.4:** Undo/trash folder
12. **Phase 1.1:** Low storage warnings
13. **Phase 6.1:** Dark mode testing
14. **Phase 6.2:** Accessibility audit

---

## Files to Create

1. `Service/StorageManager.swift` - Storage monitoring
2. `Service/AppStateManager.swift` - State persistence
3. `Service/FileCleanupService.swift` - Orphan file cleanup
4. `Service/TranscriptionQueue.swift` - Queue management
5. `Service/SystemStatusMonitor.swift` - Battery, power mode
6. `Views/Components/MissingFileAlert.swift` - Reusable alert
7. `Views/Components/StorageWarningSheet.swift` - Storage alert

## Files to Modify

1. `Service/Recorder.swift` - Interruptions, background mode
2. `Service/Player.swift` - Singleton, memory management
3. `Service/TranscriptionService.swift` - Progress, errors, retry
4. `Models/Recording.swift` - File validation, cleanup
5. `Views/Recording/Recorder/RecorderControl.swift` - Warnings, storage checks
6. `Views/Recording/RecordingForm/RecordingFormView.swift` - Save flow, validation
7. `App/Transcription_AppApp.swift` - State persistence, crash recovery
8. All playback views - Missing file checks

---

## Testing Checklist

After each phase, test:
- [ ] App backgrounding during operation
- [ ] Force quit and relaunch
- [ ] Low storage scenarios
- [ ] Phone call interruption
- [ ] Bluetooth disconnect
- [ ] Very long recordings (1+ hour)
- [ ] Silent audio files
- [ ] Missing/deleted audio files
- [ ] Rapid button tapping
- [ ] Dark mode appearance
- [ ] VoiceOver navigation

---

## Notes

- Each phase builds on previous ones
- Prioritize based on user impact and data safety
- Test thoroughly after each phase
- Consider adding unit tests for critical services (StorageManager, AppStateManager)
- Document any breaking changes or migration needs

