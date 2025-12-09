# App Backgrounding During Transcription - Implementation Summary

## Overview
This implementation handles the edge case where a user backgrounds the app while transcription is in progress. The app now properly saves state, attempts to continue transcription, and gracefully recovers when the user returns.

## Changes Made

### 1. TranscriptionProgressSheet.swift
**Location:** `Transcription App/Views/Recording/TranscriptionProgress/TranscriptionProgressSheet.swift`

**Added scenePhase monitoring to handle app lifecycle during active transcription:**

- Added `@Environment(\.scenePhase)` to track app lifecycle (line 10)
- Added `wasBackgrounded` state flag to track backgrounding (line 14)
- Added `onChange(of: scenePhase)` handler (lines 136-168) that:
  - On background: Saves current transcription state
  - On return from background:
    - If transcription completed: Navigate to details
    - If transcription interrupted: Restart transcription automatically
    - If transcription still running: Continue normally

**Key behavior:**
- Automatically resumes interrupted transcriptions
- Seamless UX - user doesn't need to manually retry

### 2. RecordingFormView.swift
**Location:** `Transcription App/Views/Recording/RecordingForm/RecordingFormView.swift`

**Enhanced scenePhase handling with better recovery logic:**

- Enhanced `onChange(of: scenePhase)` handler (lines 180-197) to:
  - Call `viewModel.markBackgrounded()` when backgrounded during transcription
  - Call `viewModel.handleReturnFromBackground()` when app returns to foreground
  - Save recording state before app suspension

**Key behavior:**
- Saves recording state before app suspension
- Automatically resumes transcription on return if interrupted

### 3. RecordingFormViewModel.swift
**Location:** `Transcription App/ViewModels/RecordingFormViewModel.swift`

**Added transcription interruption handling:**

- Added `wasBackgroundedDuringTranscription` flag (line 22)
- Added `markBackgrounded()` method (lines 382-385) to track backgrounding
- Added `handleReturnFromBackground()` method (lines 387-418) to:
  - Check if transcription completed while backgrounded
  - Detect if transcription was interrupted by iOS
  - Automatically restart transcription if needed
  - Update UI state appropriately

**Key behavior:**
- Tracks whether app was backgrounded during active transcription
- Automatically detects and recovers from interrupted transcriptions
- Reuses existing TranscriptionService queue system

## How It Works

### Scenario 1: User backgrounds during RecordingFormView transcription
1. User finishes recording, RecordingFormView starts transcription
2. User backgrounds app → `RecordingFormView.onChange(scenePhase)` triggers
3. Recording is saved with current metadata and `.inProgress` status
4. `viewModel.markBackgrounded()` is called
5. iOS may suspend the transcription task
6. User returns → `viewModel.handleReturnFromBackground()` is called
7. System checks if transcription is still active via `TranscriptionProgressManager`
8. If interrupted: Automatically restarts transcription
9. If completed: Updates UI with results
10. If still running: Continues normally

### Scenario 2: User backgrounds during TranscriptionProgressSheet
1. User navigates to RecordingsView, taps in-progress recording
2. TranscriptionProgressSheet displays with live progress
3. User backgrounds app → `TranscriptionProgressSheet.onChange(scenePhase)` triggers
4. `wasBackgrounded` flag is set
5. iOS may suspend the transcription task
6. User returns → scenePhase change handler detects return
7. System checks transcription status and active tasks
8. If interrupted: Calls `startTranscription()` to resume
9. If completed: Navigates to RecordingDetailsView
10. If still running: Continues normally

### Scenario 3: App completely quits during transcription
**Already handled by existing code:**
- Recording saved with `.inProgress` status before transcription starts
- On app relaunch, RecordingsView shows recording with "Transcribing..." status
- User can tap to view progress or manually restart transcription
- Existing `recoverIncompleteRecordings()` logic handles this case

## Reused Existing Code

This implementation leverages existing infrastructure:

- **TranscriptionProgressManager**: Used to track active transcriptions and detect interruptions
- **Auto-save mechanism**: RecordingFormView already auto-saves before transcription
- **TranscriptionService queue**: Handles sequential transcription, cancellation, and restart
- **Recording status system**: `.notStarted`, `.inProgress`, `.completed`, `.failed` states
- **TranscriptionProgressSheet**: Already used by RecordingsView for in-progress recordings

## Edge Cases Handled

✅ User backgrounds during RecordingFormView transcription
✅ User backgrounds during TranscriptionProgressSheet
✅ Transcription completes while backgrounded (rare but possible for short audio)
✅ Transcription interrupted by iOS suspension
✅ Multiple background/foreground cycles
✅ User navigates away from RecordingFormView while transcribing (existing auto-save handles this)
✅ App completely quits during transcription (existing recovery handles this)

## User Experience

**When user backgrounds during transcription:**
- Recording is automatically saved with current metadata
- Transcription attempts to continue in background (iOS permitting)
- On return, transcription automatically resumes if interrupted
- No manual intervention required from user

**If transcription can't continue in background:**
- Recording saved with `.inProgress` status
- User returns to see in-progress recording in list
- Can tap to view/resume transcription
- Transcription automatically restarts

**Best case:** Transcription continues seamlessly
**Worst case:** Recording saved, user can resume with one tap

## Testing on Device

Since iOS Simulator has limited audio support, test this implementation on a real device:

1. **Test backgrounding during initial transcription:**
   - Record audio
   - Start transcription
   - Immediately press home button
   - Wait 5-10 seconds
   - Return to app
   - Verify transcription resumes automatically

2. **Test backgrounding mid-transcription:**
   - Record longer audio (30+ seconds)
   - Let transcription start and reach ~30% progress
   - Background the app
   - Return after 10 seconds
   - Verify transcription resumes from beginning

3. **Test from recordings list:**
   - Find a recording with `.inProgress` status
   - Tap to open TranscriptionProgressSheet
   - Background the app
   - Return after 5 seconds
   - Verify transcription continues or restarts

4. **Test completion while backgrounded:**
   - Record very short audio (2-3 seconds)
   - Start transcription
   - Immediately background
   - Wait for transcription to complete
   - Return to app
   - Verify it navigates to completed recording

## Debug Logs

Look for these log messages to verify behavior:

- `📱 [TranscriptionProgressSheet] App backgrounded during transcription`
- `📱 [TranscriptionProgressSheet] App returned from background`
- `⚠️ [TranscriptionProgressSheet] Transcription was interrupted - restarting`
- `📱 [RecordingForm] Backgrounded during transcription`
- `⚠️ [RecordingForm] Transcription was interrupted - restarting`
- `✅ [RecordingForm] Transcription completed while backgrounded`
