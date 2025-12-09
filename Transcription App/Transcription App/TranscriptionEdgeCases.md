# Transcription Edge Cases & Error Scenarios

This document outlines all edge cases and error scenarios that need to be handled in the transcription system.

## ✅ Already Handled

1. **Transcription Queue Management** - Sequential queue prevents multiple simultaneous transcriptions
2. **Recording Deletion During Transcription** - Cancels transcription and removes from queue
3. **Recording Deleted Before Result Save** - Checks if recording exists before updating
4. **Duplicate Transcription Prevention** - Prevents starting same transcription twice
5. **Task Cancellation** - Handles CancellationError gracefully
6. **Incomplete Transcription Recovery** - Marks in-progress recordings as failed on app restart

## ❌ Not Yet Handled

### 2. File System Issues

#### Audio File Deleted/Moved During Transcription

- **Problem**: User or system deletes audio file while transcribing
- **Impact**: Transcription fails with `fileNotFound` error
- **Current State**: Throws error, but may not handle gracefully in all cases
- **Needed**: Verify file exists before starting AND during transcription, handle gracefully

#### Audio File Corrupted

- **Problem**: File exists but is corrupted/invalid format
- **Impact**: WhisperKit may crash or return garbage
- **Current State**: No validation before transcription
- **Needed**: Validate audio file format/duration before starting

#### Insufficient Disk Space

- **Problem**: No space to save transcription results
- **Impact**: Transcription succeeds but save fails
- **Current State**: Error handling exists but may not be user-friendly
- **Needed**: Check disk space, show clear error message

#### File Permissions Issues

- **Problem**: File exists but app lost read permissions
- **Impact**: Transcription fails silently
- **Current State**: No permission check
- **Needed**: Verify file is readable before starting

### 3. Model/Service Issues

#### Model Download Fails

- **Problem**: Network issue or storage full during model download
- **Impact**: Transcription never starts, no clear error
- **Current State**: Throws `initializationFailed` but may not be user-friendly
- **Needed**: Better error messages, retry logic, offline detection

#### Model Initialization Fails

- **Problem**: WhisperKit fails to initialize model (corrupted, incompatible)
- **Impact**: All transcriptions fail
- **Current State**: Throws error, but no recovery path
- **Needed**: Retry logic, fallback, clear error message

#### WhisperKit Crashes/Throws Unexpected Errors

- **Problem**: WhisperKit throws non-standard errors
- **Impact**: Transcription fails with unclear error
- **Current State**: Generic error handling
- **Needed**: Specific error handling, logging, user-friendly messages

#### Model Warm-up Fails

- **Problem**: Warm-up transcription fails but model exists
- **Impact**: May proceed with uninitialized model
- **Current State**: Marks as ready anyway (line 460)
- **Needed**: Better handling, retry warm-up, or fail gracefully

### 4. Queue/Concurrency Issues

#### Queue State Corruption

- **Problem**: Queue state becomes inconsistent (e.g., activeTranscriptionId doesn't match reality)
- **Impact**: Queue stuck, transcriptions never start
- **Current State**: No validation or recovery
- **Needed**: Queue state validation, recovery mechanism

#### Deadlock in Queue Management

- **Problem**: Queue lock held too long or circular wait
- **Impact**: App freezes, transcriptions hang
- **Current State**: Uses NSLock, but no timeout
- **Needed**: Timeout mechanism, deadlock detection

#### Queue Position Updates Fail

- **Problem**: ProgressManager update fails, UI shows wrong state
- **Impact**: User sees incorrect queue status
- **Current State**: No error handling for progress updates
- **Needed**: Retry logic, fallback UI state

### 5. Database/State Issues

#### Database Save Fails After Transcription

- **Problem**: Transcription succeeds but ModelContext.save() fails
- **Impact**: Transcription lost, recording still shows in-progress
- **Current State**: Error handling exists but may not retry
- **Needed**: Retry save logic, better error recovery

#### ModelContext Invalidated

- **Problem**: Context becomes invalid during transcription
- **Impact**: Can't save results, transcription lost
- **Current State**: May crash or fail silently
- **Needed**: Validate context before save, handle invalidation

#### Recording Status Inconsistency

- **Problem**: Status says `.inProgress` but no active transcription
- **Impact**: User can't retry, stuck state
- **Current State**: Only recovered on app restart
- **Needed**: Runtime detection and recovery

#### Multiple ModelContexts

- **Problem**: Different contexts used for same recording
- **Impact**: Changes not reflected, save conflicts
- **Current State**: May occur if contexts aren't synced
- **Needed**: Ensure single source of truth, context coordination

### 6. User Interaction Issues

#### User Closes TranscriptionProgressSheet

- **Problem**: User dismisses sheet while transcription queued/active
- **Impact**: Transcription continues but user has no feedback
- **Current State**: Transcription continues in background
- **Needed**: Option to cancel, or clear indication it's still running

#### User Navigates Away During Transcription

- **Problem**: User leaves RecordingFormView while transcribing
- **Impact**: Transcription continues but no progress shown
- **Current State**: Continues in background
- **Needed**: Better state management, progress visibility

#### User Tries to Edit Recording During Transcription

- **Problem**: User opens edit while transcription in progress
- **Impact**: May cause conflicts, unclear behavior
- **Current State**: Unclear if prevented
- **Needed**: Prevent editing during transcription, or handle gracefully

### 7. Resource Issues

#### Out of Memory

- **Problem**: Device runs out of memory during transcription
- **Impact**: App crashes, transcription lost
- **Current State**: No memory monitoring
- **Needed**: Monitor memory, cancel gracefully if needed

#### Device Overheating

- **Problem**: Transcription causes device to overheat
- **Impact**: System throttles/kills process
- **Current State**: No thermal monitoring
- **Needed**: Monitor thermal state, pause if needed

#### Battery Low

- **Problem**: Device battery critically low
- **Impact**: System may kill background processes
- **Current State**: No battery monitoring
- **Needed**: Check battery level, warn user, pause if critical

### 8. Recovery Issues

#### Stuck In-Progress Status

- **Problem**: Recording marked `.inProgress` but no active transcription
- **Impact**: User can't retry, stuck state
- **Current State**: Only recovered on app restart
- **Needed**: Runtime detection and recovery

#### Orphaned Transcription Tasks

- **Problem**: Task registered but never completes or cancels
- **Impact**: Queue stuck, resources held
- **Current State**: No cleanup mechanism
- **Needed**: Task timeout, orphan detection, cleanup

#### Queue Not Processing

- **Problem**: Queue has items but nothing starts
- **Impact**: User waits indefinitely
- **Current State**: No watchdog or recovery
- **Needed**: Queue health check, auto-recovery

### 9. Progress Tracking Issues

#### Progress Callback Fails

- **Problem**: Progress callback throws error
- **Impact**: UI doesn't update, but transcription continues
- **Current State**: No error handling in callback
- **Needed**: Wrap callback in try-catch, handle gracefully

#### Progress Goes Backward

- **Problem**: Progress decreases (shouldn't happen but could)
- **Impact**: Confusing UI, user thinks it's broken
- **Current State**: Has monotonic check, but may not be perfect
- **Needed**: Ensure progress never decreases

#### Progress Stuck at Same Value

- **Problem**: Progress doesn't update for long time
- **Impact**: User thinks transcription is stuck
- **Current State**: No timeout detection
- **Needed**: Detect stuck progress, show indication or retry

### 10. Audio File Issues

#### Very Long Recordings

- **Problem**: Extremely long audio files may cause memory issues
- **Impact**: Transcription fails or crashes
- **Current State**: No length validation
- **Needed**: Check duration, warn or split if too long

#### Silent/Empty Recordings

- **Problem**: Recording has no audio or is completely silent
- **Impact**: Transcription returns empty (handled, but may confuse user)
- **Current State**: Returns empty result, which is correct
- **Needed**: Better user messaging for empty results

#### Unsupported Audio Format

- **Problem**: Audio file format not supported by WhisperKit
- **Impact**: Transcription fails
- **Current State**: May fail with unclear error
- **Needed**: Validate format before starting, convert if needed

## Priority Recommendations

### High Priority

1. App backgrounded during transcription
2. Audio file deleted during transcription
3. Database save failures
4. Queue state corruption recovery
5. Stuck in-progress status detection

### Medium Priority

6. Model download/initialization failures
7. Memory/thermal monitoring
8. Progress tracking robustness
9. User interaction edge cases

### Low Priority

10. Very long recordings
11. Format validation
12. Battery monitoring
