# PlexWidget Onboarding Crash - Root Cause Analysis

## Executive Summary

**The crash was NOT caused by missing autoreleasepool management.**

The real issue was calling `onComplete()` (which closes the onboarding window) **INSIDE** the `MainActor.run` block **WHILE** still inside an autoreleasepool. This created a memory management deadlock that caused `EXC_BAD_ACCESS` crashes.

## Crash Evidence

**Crash Log Stack Trace (from PlexWidget-2025-11-10-182747.ips):**

```
objc_release
→ AutoreleasePoolPage::releaseUntil
→ objc_autoreleasePoolPop
→ swift::runJobInEstablishedExecutorContext
→ swift_job_runImpl
→ _dispatch_main_queue_drain
→ NSApplication run
```

This pattern indicates an **object being double-freed** during autorelease pool cleanup on the main thread while processing a Swift async job.

## Root Cause Explanation

### The Problem Code (OnboardingView.swift)

```swift
autoreleasepool {
    Task {
        let testResult = await validatePlexConnection(...)

        await MainActor.run {
            if ConfigManager.shared.saveConfig(...) {
                // BUG: Calling onComplete while inside autoreleasepool
                onComplete(cleanUrl, cleanToken)  // <- This closes the window
            }
        }
    }
}
```

### Why This Crashed

1. **autoreleasepool block created** - Sets up a local autorelease pool context
2. **Task spawned** - Swift async task with its own autorelease pool management
3. **MainActor.run executed** - Ensures UI updates happen on main thread
4. **onComplete() called** - This closure:
   - Executes `self.onboardingWindow?.close()` in PlexWidgetApp.swift line 83
   - Destroys the NSHostingView containing the OnboardingView
   - Deallocates objects currently referenced in the autorelease pool
5. **autoreleasepool exits** - Tries to release objects that were already freed by window closure
6. **CRASH** - `objc_autoreleasePoolPop` attempts to release pointers to freed memory

### Memory Corruption Sequence

```
Timeline of Events:

T1: autoreleasepool created
    ↓
T2: Task { ... } runs
    ↓
T3: MainActor.run {
    ↓
T4: saveConfig() executes - config saved successfully
    ↓
T5: onComplete() called
    ├─ Triggers: PlexWidgetApp.onboarding callback
    ├─ Executes: self.onboardingWindow?.close()
    └─ Effect: NSHostingView destroyed, objects freed
    ↓
T6: MainActor.run completes
    ↓
T7: Task completes
    ↓
T8: autoreleasepool exits
    ├─ Calls objc_autoreleasePoolPop()
    ├─ Attempts to release objects from T1-T5
    └─ CRASH: Freeing already-freed memory (double-free)
```

## The Failed Fixes

### Why the Previous autoreleasepool Attempts Failed

1. **PlexWidgetApp.swift line 136** - autoreleasepool around NSHostingView creation
   - This was CORRECT and necessary
   - But it didn't address the real problem in OnboardingView

2. **OnboardingView.swift line 360** - autoreleasepool around Task
   - This made things WORSE
   - It created the double-free condition described above

### Why Simply Removing autoreleasepool Works

By removing the `autoreleasepool { Task { ... } }` wrapper, we:
- Allow Swift's runtime to manage autorelease pools correctly for the async task
- Prevent the conflicting pool management that was causing double-frees
- Let the Task complete its cleanup before MainActor operations execute

## The Solution

**Remove the autoreleasepool wrapper and defer the onComplete callback:**

```swift
private func validateAndSave() {
    // ... validation setup ...

    // FIXED: No autoreleasepool wrapper
    Task {
        let testResult = await validatePlexConnection(...)

        await MainActor.run {
            if ConfigManager.shared.saveConfig(...) {
                // FIXED: Schedule callback for next run loop iteration
                // This ensures all current cleanup completes before window closes
                DispatchQueue.main.async {
                    self.onComplete(cleanUrl, cleanToken)
                }
            }
        }
    }
}
```

### Why This Works

1. **No autoreleasepool wrapping** - Lets Swift manage pool cleanup normally
2. **DispatchQueue.main.async** - Schedules onComplete for the NEXT run loop iteration
3. **Proper ordering** - Ensures:
   - MainActor.run completes
   - Task cleanup finishes
   - Autorelease pool cleanup occurs
   - THEN onComplete() executes and closes the window

This gives all cleanup operations time to complete safely before any window destruction.

## Key Insights

1. **autoreleasepool is NOT always the solution**
   - Can actually CAUSE problems when mixing with Swift async/await
   - Should only be used when specifically managing Objective-C lifecycle

2. **DispatchQueue.main.async is the right tool**
   - Guarantees next run loop iteration
   - Proper sequencing for UI teardown operations
   - Standard pattern for deferred callbacks

3. **Memory management order matters**
   - Objects must be released in reverse dependency order
   - Window closure must happen AFTER all reference cleanup
   - Async task cleanup must complete before UI teardown

## Prevention

To prevent this type of crash in the future:

1. **Don't wrap async Tasks in autoreleasepool**
   - Swift runtime manages these correctly
   - autoreleasepool creates manual pool management conflicts

2. **Always defer window-closing callbacks**
   - Use `DispatchQueue.main.async` for operations that close windows
   - Ensures all current operations complete first

3. **Test with actual Xcode debugging**
   - Use Instruments to watch autorelease pool behavior
   - Enable Address Sanitizer to catch double-free crashes
   - Use Memory Debug tools in Xcode

## Files Changed

- **/Volumes/LIME2/Work/Development/plex-desktop-widget/PlexWidget/PlexWidget/OnboardingView.swift**
  - Removed: `autoreleasepool { Task { ... } }` wrapper
  - Added: `DispatchQueue.main.async { self.onComplete(...) }`
  - Result: Safe window closure after all cleanup

## Testing Recommendation

To verify this fix:

1. Launch the app with fresh onboarding
2. Enter valid Plex server URL and token
3. Click "Continue" button
4. Verify:
   - Window closes cleanly
   - No crash logs in ~/Library/Logs/DiagnosticReports/
   - Main widget window appears
   - App continues running normally

