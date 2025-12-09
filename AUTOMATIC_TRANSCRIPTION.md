# Automatic Transcription System

## Overview
Transcriptions now start automatically without user intervention. The queue is managed automatically, and users see clear queue positions in the recording list UI.

## How It Works

### 1. Auto-Start on Recording Completion
**When:** User finishes recording
**Where:** `RecordingFormView`
**What Happens:**
1. Recording auto-saved with `.notStarted` status
2. `startTranscriptionIfNeeded()` called automatically
3. Transcription begins immediately (or queues if another is active)
4. User sees progress in RecordingFormView

### 2. Auto-Start on App Launch
**When:** App opens or user returns to RecordingsView
**Where:** `RecordingsView.recoverIncompleteRecordings()`
**What Happens:**
1. Finds all recordings with `.inProgress` or `.notStarted` status
2. Filters for recordings with valid audio URLs
3. Skips recordings already transcribing/queued
4. Starts background transcription for each pending recording
5. Registers tasks with TranscriptionProgressManager

**Code:** RecordingsView.swift:343-374, 259-340

### 3. Auto-Resume on Sheet Open
**When:** User taps in-progress recording
**Where:** `TranscriptionProgressSheet`
**What Happens:**
1. Sheet checks recording status on appear
2. If `.inProgress`, starts transcription automatically
3. Shows live progress or queue position
4. Auto-navigates to details on completion

## Queue Position Display

### Format
- **Actively transcribing:** "Transcribing 45% (1/3)"
- **Waiting in queue:** "Waiting to transcribe (2/3)"
- **Preparing:** "Preparing to transcribe..."
- **Interrupted:** "[Custom failure message]. Tap to resume."

### Implementation
**Where:** `RecordingRowView.swift:65-105`

**Logic:**
```swift
if let position = progressManager.getOverallPosition(for: recording.id),
   let totalSize = progressManager.getTotalQueueSize() {
    if position == 1 {
        // Show "Transcribing (1/3)"
    } else {
        // Show "Waiting to transcribe (2/3)"
    }
}
```

**Queue Position Calculation:**
- Position 1 = actively transcribing
- Position 2+ = waiting in queue
- Total size = active + queued recordings

**Code:** TranscriptionProgressManager.swift:105-123

## User Experience

### Happy Path
1. **Record audio** → Auto-saves
2. **Recording ends** → Transcription starts automatically
3. **View recordings list** → See "Transcribing (1/1)" with progress
4. **Wait** → Transcription completes automatically
5. **Open recording** → See full transcript

### Multiple Recordings Path
1. **Record 3 audio files quickly**
2. **First recording** → "Transcribing 30% (1/3)"
3. **Second recording** → "Waiting to transcribe (2/3)"
4. **Third recording** → "Waiting to transcribe (3/3)"
5. **As each completes** → Queue advances automatically
6. **All complete** → All show full transcripts

### Interrupted Path
1. **Recording transcribing** → User backgrounds app
2. **iOS suspends transcription**
3. **User returns** → Auto-resumes transcription
4. **Or:** User reopens app later → Auto-starts on launch
5. **Queue shows correct position**

### Error Path
1. **Transcription fails** → Saved as `.inProgress`
2. **Shows:** "Transcription was interrupted. Tap to resume."
3. **User ignores it** → Next app launch auto-retries
4. **Or:** User taps → TranscriptionProgressSheet opens → Auto-starts

## No Manual Buttons Needed

**Removed/Never Added:**
- ❌ "Start Transcription" button
- ❌ "Retry Transcription" button
- ❌ "Resume" button

**Why:**
- Everything happens automatically
- Simpler MVP UX
- Less cognitive load for users
- Fewer edge cases to handle

**Users Can Still:**
- ✅ View progress by opening recordings
- ✅ See queue position in list
- ✅ Cancel by deleting recording
- ✅ Resume by tapping (auto-triggers)

## Code Architecture

### Files Modified

1. **RecordingsView.swift** (lines 259-374)
   - Added `startBackgroundTranscription()` method
   - Updated `recoverIncompleteRecordings()` to auto-start
   - Auto-starts all pending transcriptions on appear

2. **RecordingRowView.swift** (lines 65-105)
   - Shows queue position (e.g., "2/3")
   - Shows progress percentage for active
   - Shows waiting message for queued
   - Handles interrupted state

3. **TranscriptionProgressManager.swift** (lines 105-123)
   - Added `getTotalQueueSize()` method
   - Added `getOverallPosition()` method
   - Returns position including active transcription

### Background Transcription Logic

**Flow:**
```
RecordingsView.recoverIncompleteRecordings()
  → For each pending recording:
    → startBackgroundTranscription(recording)
      → Task { @MainActor in
        → TranscriptionService.shared.transcribe()
          → Updates progress via callback
          → Saves result to database
          → Cleans up on completion/error
        }
      → TranscriptionProgressManager.registerTask()
```

**Error Handling:**
- All errors → Save as `.inProgress` with retry message
- Cancellation → Clean up gracefully
- Deletion during transcription → Detect and abort
- Queue state corruption → Auto-recovery (from queue management)

## Edge Cases Handled

### 1. App Launch with Multiple Pending
- All pending recordings auto-start
- Queue managed automatically
- UI shows correct positions

### 2. Recording Deleted During Transcription
- Task checks if recording exists
- Aborts gracefully if deleted
- No errors shown to user

### 3. Transcription Fails
- Saved as `.inProgress` (not `.failed`)
- Shows retry message
- Auto-retries on next app launch

### 4. App Backgrounded
- Transcription continues if possible
- If interrupted, auto-resumes on return
- Queue state preserved

### 5. Multiple App Launches
- Idempotent - doesn't double-start
- Checks if already transcribing/queued
- Skips recordings already in progress

### 6. No Audio File
- Filtered out before starting
- Checks `recording.resolvedURL != nil`
- No errors or crashes

## Testing Scenarios

### Test 1: Single Recording
1. Record audio
2. Verify auto-starts immediately
3. Verify shows "Transcribing (1/1)"
4. Wait for completion
5. Verify shows full transcript

**Expected:** Automatic, no user action needed

### Test 2: Multiple Recordings
1. Record 3 audio files quickly
2. Verify first shows "Transcribing (1/3)"
3. Verify second shows "Waiting (2/3)"
4. Verify third shows "Waiting (3/3)"
5. Wait for all to complete
6. Verify all show transcripts

**Expected:** Queue positions update as transcriptions complete

### Test 3: App Launch with Pending
1. Force quit app during transcription
2. Relaunch app
3. Navigate to RecordingsView
4. Verify transcription auto-starts
5. Verify queue position shown

**Expected:** Auto-resumes on launch

### Test 4: Background and Return
1. Start transcription
2. Background app
3. Wait 10 seconds
4. Return to app
5. Verify transcription continues or resumes

**Expected:** Seamless continuation

### Test 5: Delete During Transcription
1. Start transcription
2. Delete recording immediately
3. Verify no errors
4. Verify task cleans up gracefully

**Expected:** Silent cleanup, no crashes

## Debug Logs

Look for these logs:

**Auto-Start:**
- `🔄 [Auto-Start] Found X recording(s) needing transcription`
- `✅ [Auto-Start] Starting transcription for: [title]`
- `🎯 [Auto-Start] Starting transcription for: [filename]`
- `✅ [Auto-Start] Transcription completed for: [title]`

**Errors:**
- `❌ [Auto-Start] No audio URL for recording: [title]`
- `❌ [Auto-Start] Transcription error: [error]`
- `ℹ️ [Auto-Start] Recording was deleted during transcription`
- `ℹ️ [Auto-Start] Transcription cancelled for recording: [id]`

**Queue:**
- See queue management logs from QUEUE_MANAGEMENT.md

## Benefits

✅ **Zero manual interaction** - Everything automatic
✅ **Clear queue visibility** - Users see position (2/3)
✅ **Simpler UX** - No buttons, no decisions
✅ **Self-healing** - Auto-retries on errors
✅ **Background friendly** - Works with app lifecycle
✅ **MVP-ready** - Clean, simple, functional
✅ **Scalable** - Handles multiple recordings elegantly

## Philosophy

**Automatic by Default**
- Transcription starts immediately after recording
- Pending transcriptions start on app launch
- No user intervention required
- Queue managed invisibly

**Progressive Disclosure**
- Basic: Just see progress in list
- Advanced: Tap to see detailed progress
- Error: Clear message with auto-retry

**Fail Gracefully**
- Errors don't block queue
- Auto-retry on next launch
- Clear messaging for users
- No data loss
