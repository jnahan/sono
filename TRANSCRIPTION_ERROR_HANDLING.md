# Comprehensive Transcription Error & Interruption Handling

## Overview
This implementation ensures all transcription failures and interruptions are handled gracefully. Instead of marking recordings as "failed", we save them as `.inProgress` with helpful messages so users can resume transcription from the home page or transcription queue.

## Philosophy
**Graceful Recovery Over Hard Failures**
- Transcription continues in background when possible
- If interrupted, recording is saved with `.inProgress` status
- Users can resume from home page with one tap
- Clear, actionable messages guide users
- No complicated error states - simple resume flow

## Edge Cases Handled

### 1. ✅ Low Memory Warning
**Scenario:** iOS sends memory warning during transcription

**Handling:**
- `RecordingFormView`: Detects `UIApplication.didReceiveMemoryWarningNotification`
- Immediately saves recording state
- Calls `viewModel.handleLowMemory()` to:
  - Cancel active transcription task
  - Update status to `.inProgress`
  - Set failureReason: "Transcription was interrupted due to low memory. Tap to resume."
  - Save to database
- `TranscriptionProgressSheet`: Also handles memory warnings
- User sees clear message in recordings list

**User Experience:**
- Recording appears in home page with "Transcription was interrupted due to low memory. Tap to resume."
- User taps to resume transcription
- Transcription starts from beginning (not partial)

---

### 2. ✅ App Termination
**Scenario:** iOS terminates the app (user force-quits or system kills it)

**Handling:**
- `RecordingFormView`: Detects `UIApplication.willTerminateNotification`
- Saves recording state immediately before termination
- Status remains `.inProgress` with failureReason
- `TranscriptionProgressSheet`: Also saves on termination

**User Experience:**
- On app relaunch, recording shows in home page
- Message: "Transcription was interrupted. Tap to resume."
- User can resume immediately

---

### 3. ✅ App Backgrounding
**Scenario:** User presses home button while transcribing

**Handling:**
- Detects `scenePhase` change to `.background`
- Saves recording metadata immediately
- Marks as backgrounded via `viewModel.markBackgrounded()`
- iOS may suspend transcription task
- On return (`.active`):
  - Checks if transcription still active
  - If interrupted: Automatically restarts
  - If completed: Shows results
  - If still running: Continues normally

**User Experience:**
- Best case: Transcription continues seamlessly in background
- Worst case: Auto-resumes when user returns to app
- No manual intervention needed

---

### 4. ✅ Task Cancellation
**Scenario:** Transcription task is cancelled programmatically

**Handling:**
- `TranscriptionProgressSheet`: Catches `CancellationError`
- Updates recording to `.inProgress`
- Sets failureReason: "Transcription was interrupted. Tap to resume."
- Saves to database

**User Experience:**
- Recording appears in home page with resume message
- User can tap to restart transcription

---

### 5. ✅ Transcription Service Errors
**Scenario:** WhisperKit or transcription engine throws error

**Handling:**
- `RecordingFormViewModel.handleTranscriptionError()`:
  - Catches all errors from transcription
  - Sets status to `.inProgress` (not `.failed`)
  - Sets failureReason: "Transcription was interrupted. Tap to resume."
  - Saves to database
  - Shows toast: "Transcription was interrupted. You can resume from the home page."
- `TranscriptionProgressSheet`: Similar handling

**User Experience:**
- User sees toast notification
- Recording appears in home page with resume option
- Clear path to retry

---

### 6. ✅ Database Save Errors
**Scenario:** Saving transcription results fails

**Handling:**
- `TranscriptionProgressSheet`: Catches save errors after successful transcription
- Sets status to `.inProgress` (not `.failed`)
- Sets failureReason: "Transcription was interrupted. Tap to resume."
- User can retry to save results again

**User Experience:**
- Recording appears in home page
- User taps to resume/retry
- Transcription runs again (since results weren't saved)

---

### 7. ✅ Recording Deleted During Transcription
**Scenario:** User deletes recording while it's being transcribed

**Handling:**
- All transcription code checks if recording exists before updating
- If deleted: Silently cancels transcription, no errors shown
- Logs: "Recording was deleted, cannot start transcription"

**User Experience:**
- No errors or crashes
- Transcription stops cleanly
- No orphaned data

---

### 8. ✅ Network Issues (Future-Proof)
**Note:** Current implementation uses on-device WhisperKit (no network needed)

**Handling:**
- If future versions use cloud transcription:
- Network errors would be caught by general error handler
- Recording saved as `.inProgress`
- User can retry when network available

---

### 9. ✅ Multiple Interruptions
**Scenario:** User backgrounds app multiple times during transcription

**Handling:**
- Each background/foreground cycle is handled independently
- `wasBackgroundedDuringTranscription` flag tracks state
- On each return, checks if transcription still active
- Auto-resumes only if needed

**User Experience:**
- Seamless across multiple background/foreground cycles
- Transcription continues or auto-resumes

---

### 10. ✅ Model Loading Failures
**Scenario:** WhisperKit model fails to load or warm up

**Handling:**
- `RecordingFormViewModel.startTranscription()`:
  - Waits up to 60 seconds for model to load
  - If timeout: Shows error and saves as `.inProgress`
- Error message explains model issue
- User can retry after model loads

**User Experience:**
- Clear error message about model
- Can retry immediately or later
- Model will be ready on retry

---

## Implementation Details

### Status Management
**All errors → `.inProgress` (NOT `.failed`)**
- Consistent recovery path for all error types
- Simple user experience: "Tap to resume"
- No complex error state management

### Failure Reason Messages
**User-friendly, actionable messages:**
- ✅ "Transcription was interrupted. Tap to resume."
- ✅ "Transcription was interrupted due to low memory. Tap to resume."
- ❌ NOT: "Error code 123: TranscriptionEngine failed"

### Files Modified

1. **RecordingFormView.swift** (lines 198-212)
   - Added memory warning handler
   - Added app termination handler

2. **RecordingFormViewModel.swift** (lines 22, 342-379, 420-445)
   - Added `wasBackgroundedDuringTranscription` flag
   - Added `handleLowMemory()` method
   - Updated `handleTranscriptionError()` to save as `.inProgress`
   - Added `handleReturnFromBackground()` method

3. **TranscriptionProgressSheet.swift** (lines 10-14, 136-191, 262-314)
   - Added `scenePhase` and `wasBackgrounded` tracking
   - Added background/foreground detection
   - Added memory warning handler
   - Added app termination handler
   - Updated all error handlers to save as `.inProgress`

4. **RecordingRowView.swift** (lines 71-101)
   - Shows `failureReason` message for interrupted recordings
   - Distinguishes between active transcription and interrupted state
   - Shows progress for active, message for interrupted

## Testing Scenarios

### Test 1: Low Memory
1. Start transcribing long audio
2. Simulate memory warning (Xcode → Debug → Simulate Memory Warning)
3. Verify recording appears in home page with memory warning message
4. Tap to resume
5. Verify transcription restarts successfully

### Test 2: Force Quit
1. Start transcribing
2. Force quit app (swipe up from app switcher)
3. Relaunch app
4. Verify recording appears with "Tap to resume" message
5. Tap to resume and verify success

### Test 3: Backgrounding
1. Start transcribing
2. Press home button
3. Wait 10 seconds
4. Return to app
5. Verify transcription auto-resumes or continues

### Test 4: Network Loss (If applicable)
1. Start cloud transcription
2. Enable airplane mode
3. Verify graceful error handling
4. Disable airplane mode
5. Retry transcription

### Test 5: Multiple Backgrounds
1. Start transcribing
2. Background 3-4 times during transcription
3. Verify each time handles correctly
4. Verify eventual completion or resumption

## User Journey

### Happy Path
1. User records audio
2. Transcription starts automatically
3. Transcription completes successfully
4. Recording appears in home page with full transcript

### Interrupted Path (Any Error)
1. User records audio
2. Transcription starts
3. **Interruption occurs** (memory, background, error, etc.)
4. Recording saved as `.inProgress` with helpful message
5. Recording appears in home page
6. User sees: "Transcription was interrupted. Tap to resume."
7. User taps recording
8. `TranscriptionProgressSheet` opens
9. Transcription automatically starts
10. Completion → Recording shows in home page with transcript

## Benefits

✅ **No data loss** - All recordings saved regardless of errors
✅ **Simple recovery** - One tap to resume for all error types
✅ **Clear messaging** - Users know exactly what to do
✅ **Automatic retry** - Background/foreground automatically resumes
✅ **Consistent UX** - Same flow for all error types
✅ **No complicated logic** - Everything → `.inProgress` → Resume
✅ **Future-proof** - Handles unknown errors gracefully

## Debug Logs

Look for these logs during testing:

**Memory Warnings:**
- `⚠️ [RecordingForm] Low memory warning during transcription - saving state`
- `⚠️ [TranscriptionProgressSheet] Low memory warning - canceling transcription`

**App Termination:**
- `⚠️ [RecordingForm] App terminating during transcription - saving state`
- `⚠️ [TranscriptionProgressSheet] App terminating - saving state`

**Backgrounding:**
- `📱 [RecordingForm] Backgrounded during transcription`
- `📱 [RecordingForm] App returned from background`
- `⚠️ [RecordingForm] Transcription was interrupted - restarting`

**Errors:**
- `⚠️ [RecordingForm] Transcription error handled gracefully: [error details]`
- `⚠️ [TranscriptionProgressSheet] Transcription error handled gracefully: [error details]`

**Cancellation:**
- `ℹ️ [TranscriptionProgressSheet] Transcription cancelled for recording: [id]`
