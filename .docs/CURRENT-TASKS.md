# Plex Desktop Widget - Current Tasks

**Last Updated:** 2025-11-09

## Active Tasks

### CRITICAL: Fix DMG Icon Display Issues
**Status:** In Progress (BLOCKED - needs user screenshot/feedback)
**Priority:** High

The DMG installer has icon display problems that need to be resolved:

**Issues Identified:**
1. Icons appear cut off at the bottom
2. A faint icon is visible in the background
3. Icons may not be displaying at proper 128x128 size

**What Was Attempted:**
- Multiple iOS agent invocations to fix icon sizing
- AppleScript-based .DS_Store configuration
- Using `create-dmg` tool
- Manual hdiutil DMG creation with Applications symlink

**Current State:**
- DMG is mounted at `/Volumes/PlexWidget 1/`
- Contains PlexWidget.app and Applications symlink
- Finder window opened but user stopped the investigation before screenshot could be captured

**Next Steps:**
1. Wait for user to provide screenshot or description of the exact icon display issue
2. Research proper .DS_Store configuration for large icon display (128x128)
3. Consider using a reliable DMG creation tool like `create-dmg` with proper icon sizing parameters
4. Test the solution thoroughly before presenting to user

**Important Notes:**
- User explicitly said "STOP. look properly. there is a faint icon in the background and the main icons are cutt off at the bottom. don't rush this"
- Need to slow down and carefully examine the issue before attempting fixes
- The app code itself is working correctly (PlexWidgetApp.swift)

---

## Completed Tasks

### App Functionality - FULLY WORKING
**Status:** ✅ Completed
**Date Completed:** 2025-11-09

**What Was Fixed:**
1. **Menu Bar Icon Timing Issue** - Created `createMenuBarItem()` function that is called AFTER switching to `.accessory` mode (lines 42, 86 in PlexWidgetApp.swift)
2. **Quit Button** - Added Quit button to SettingsView panel (lines 94-109 in SettingsView.swift)
3. **DMG with Applications Symlink** - Built Release DMG with drag-to-Applications functionality

**Critical Code (DO NOT CHANGE):**
```swift
// PlexWidgetApp.swift:33-45
func applicationDidFinishLaunching(_ notification: Notification) {
    if ConfigManager.shared.loadConfig() == nil {
        NSApp.setActivationPolicy(.regular)
        showOnboarding()
    } else {
        NSApp.setActivationPolicy(.accessory)
        createMenuBarItem()  // CRITICAL: Called AFTER accessory mode
        showMainWidget()
    }
}

// PlexWidgetApp.swift:80-88 (onboarding completion)
onComplete: { [weak self] serverUrl, token in
    self?.onboardingWindow?.close()
    self?.onboardingWindow = nil
    NSApp.setActivationPolicy(.accessory)
    self?.createMenuBarItem()  // CRITICAL: Called AFTER accessory mode
    self?.showMainWidget()
}
```

**Testing Verified:**
- Onboarding shows correctly on first launch
- After onboarding completes, menu bar icon appears
- Widget window displays correctly
- Settings panel accessible from menu bar icon
- Quit button works in settings panel

---

## Files Modified This Session

### Core App Files (Working - DO NOT MODIFY)
- `PlexWidget/PlexWidget/PlexWidgetApp.swift` - App delegate with fixed menu bar timing
- `PlexWidget/PlexWidget/SettingsView.swift` - Settings panel with Quit button

### Build Artifacts
- `PlexWidget.dmg` - DMG installer (has icon display issues)

---

## Important Context

### What Works
- App code is 100% functional
- Onboarding flow works correctly
- Menu bar icon appears after setup
- Widget displays now playing info
- Settings panel with all controls
- Quit functionality

### What Doesn't Work
- DMG icon display (icons cut off, faint background icon)

### Critical Lessons Learned
1. **Menu bar icon creation MUST happen AFTER `.accessory` mode** - This was the root cause of the "onboarding yes, menu no, player no" bug
2. **Don't let debugger agent change working code** - The debugger agent broke the working solution by adding delays and changing `makeKeyAndOrderFront` to `orderFrontRegardless`
3. **User wants Quit button in settings panel, NOT in menu bar** - Don't replace the menu bar chevron icon
4. **DMG creation requires careful icon configuration** - Multiple attempts with different tools have not yet produced correct icon display

### Known Issues to Remember
- UserDefaults persists between app runs - may need `defaults delete com.plexwidget.app` for clean testing
- DMG needs proper .DS_Store configuration for large icons without cutoff

---

## Next Session Priorities

1. **HIGH:** Fix DMG icon display issues
   - Get screenshot/description from user of exact problem
   - Research proper .DS_Store icon view settings
   - Test solution thoroughly before presenting

2. **MEDIUM:** Test complete DMG installation flow
   - Clear UserDefaults: `defaults delete com.plexwidget.app`
   - Install from DMG
   - Verify onboarding appears
   - Verify menu bar icon and widget appear after setup

3. **LOW:** Consider roadmap items from ROADMAP.md if DMG is complete
   - Seamless track transitions (v1.1)
   - Mini mode (v1.1)

---

## File Structure Reference

```
PlexWidget/
├── PlexWidget/
│   ├── PlexWidgetApp.swift          # Main app delegate (WORKING - DO NOT CHANGE)
│   ├── SettingsView.swift           # Settings panel with Quit button (COMPLETE)
│   ├── WidgetSettings.swift         # Settings model
│   ├── ContentView.swift            # Main widget view
│   ├── NowPlayingView.swift         # Now playing display
│   ├── PlexAPI.swift                # Plex API client
│   ├── MediaRemoteController.swift  # Media controls
│   └── Config.swift                 # Configuration management
├── PlexWidget.xcodeproj/
└── ...
PlexWidget.dmg                        # DMG installer (NEEDS ICON FIX)
ROADMAP.md                            # Future features planned
```

---

## Git Status

**Current Branch:** main

**Staged/Modified Files:**
- PlexWidget/PlexWidget/PlexWidgetApp.swift (Modified)
- PlexWidget/PlexWidget/SettingsView.swift (New file)
- PlexWidget/PlexWidget/WidgetSettings.swift (New file)
- Other modified files in PlexWidget/ directory

**Note:** No git commits were made this session. Consider committing the working app code before making DMG-related changes.
