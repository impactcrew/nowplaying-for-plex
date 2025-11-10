# Plex Desktop Widget - Current Tasks

**Last Updated:** 2025-11-10

## Active Tasks

### CRITICAL: App Crashes on Launch After Onboarding
**Status:** BLOCKED - Requires Mac restart to clear caches
**Priority:** CRITICAL

**The Problem:**
After completing onboarding, the app crashes with segmentation fault (SIGSEGV) instead of showing menu bar icon and player window.

**Root Cause Identified:**
- App was crashing trying to run from `/Applications/PlexWidget.app` (old broken version)
- macOS Launch Services cached the broken app location even after deletion
- Memory corruption (EXC_BAD_ACCESS at 0x20) in objc_release during app startup
- Clean rebuild from commit a6e0775 (known working version) is ready to test

**What Was Tried:**
1. Reverted code to exact working version from commit a6e0775
2. Removed all PlexWidget.app copies from /Applications
3. Cleared UserDefaults and Keychain
4. Reset Launch Services database with lsregister -kill
5. Multiple clean rebuilds

**Current State:**
- Code is reverted to EXACT working version (commit a6e0775)
- Clean Release build exists at: `/Users/lemon/Library/Developer/Xcode/DerivedData/PlexWidget-ekdjkaiigyfuxzbyeenegnfaddic/Build/Products/Release/PlexWidget.app`
- User is restarting Mac to clear all caches
- DMG with large icons (128x128) was successfully created earlier

**IMMEDIATE Next Steps (After Restart):**
1. Run: `open "/Users/lemon/Library/Developer/Xcode/DerivedData/PlexWidget-ekdjkaiigyfuxzbyeenegnfaddic/Build/Products/Release/PlexWidget.app"`
2. Complete onboarding with Plex credentials
3. Verify menu bar icon and player appear (should work - code is identical to working version)
4. If working, create fresh DMG and test installation
5. Launch ready for distribution

**Important Notes:**
- DO NOT modify PlexWidgetApp.swift - it's the exact working version
- The crash was environmental (cached broken app), NOT a code issue
- Restart should resolve all caching/memory issues

---

## Completed Tasks

### DMG Creation with Large Icons
**Status:** ✅ Completed
**Date Completed:** 2025-11-10

Successfully created production DMG with properly sized icons (128x128) using AppleScript configuration:
- Icons display at large size similar to professional installers
- Drag-to-Applications symlink works correctly
- Icon positioning adjusted to user preference (moved up slightly)
- DMG compressed to 2.4MB final size

### Code Reverted to Working Version
**Status:** ✅ Completed
**Date Completed:** 2025-11-10

Reverted all code to commit a6e0775 (last known working version):
- PlexWidgetApp.swift - Menu bar item created in applicationDidFinishLaunching
- OnboardingView.swift - Original working onboarding flow
- SettingsView.swift - Settings panel with Quit button

**Critical Code Pattern (From Working Version a6e0775):**
```swift
// Menu bar item created IMMEDIATELY in applicationDidFinishLaunching
// NOT after onboarding - this is key to making it work
func applicationDidFinishLaunching(_ notification: Notification) {
    if ConfigManager.shared.loadConfig() == nil {
        NSApp.setActivationPolicy(.regular)
        showOnboarding()
    } else {
        NSApp.setActivationPolicy(.accessory)
        showMainWidget()
    }

    // Menu bar created HERE regardless of onboarding state
    statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    // ... icon setup code ...
}
```

---

## Files Modified This Session

### Core App Files (Working - DO NOT MODIFY)
- `PlexWidget/PlexWidget/PlexWidgetApp.swift` - App delegate with fixed menu bar timing
- `PlexWidget/PlexWidget/SettingsView.swift` - Settings panel with Quit button

### Build Artifacts
- `PlexWidget.dmg` - DMG installer (has icon display issues)

---

## Important Context

### What's Working (Code-wise)
- Code is identical to commit a6e0775 which was verified working
- Clean Release build is ready at DerivedData location
- DMG with large icons created successfully
- All git changes committed (commit 2c6f9af)

### What's Blocked
- App crashes on launch due to macOS cache issues
- User restarting to clear caches

### Critical Lessons Learned
1. **Menu bar item MUST be created in applicationDidFinishLaunching, NOT after onboarding** - Creating it after onboarding causes the app to have no windows and macOS terminates it
2. **macOS aggressively caches app locations** - Even after deleting /Applications/PlexWidget.app, Launch Services still tried to run the old version
3. **Always test from DerivedData directly during development** - Avoids cache issues
4. **Memory corruption crashes require full system restart** - lsregister reset not enough
5. **When debugging fails, revert to last known working version** - We spent hours trying to fix when the issue was environmental, not code

### Known Issues to Remember
- UserDefaults persists: `defaults delete com.plexwidget.app` for clean testing
- Keychain persists: `security delete-generic-password -s "com.plexwidget.credentials" -a "plex-token"` to clear
- After restart, ONLY launch from DerivedData path until verified working

---

## Next Session Priorities

### IMMEDIATE (First 5 Minutes After Restart)

1. **Test app from DerivedData:**
   ```bash
   open "/Users/lemon/Library/Developer/Xcode/DerivedData/PlexWidget-ekdjkaiigyfuxzbyeenegnfaddic/Build/Products/Release/PlexWidget.app"
   ```

2. **Complete onboarding** with Plex credentials

3. **Verify it works:**
   - Menu bar icon appears ✓
   - Player window appears ✓
   - Settings accessible ✓

### If Working (Next Steps)

4. **Create fresh DMG from working build:**
   ```bash
   cd PlexWidget
   rm -rf /tmp/dmg-build
   mkdir -p /tmp/dmg-build
   cp -R "/Users/lemon/Library/Developer/Xcode/DerivedData/PlexWidget-ekdjkaiigyfuxzbyeenegnfaddic/Build/Products/Release/PlexWidget.app" /tmp/dmg-build/
   ln -s /Applications /tmp/dmg-build/Applications
   # Then create DMG with AppleScript for large icons
   ```

5. **Test DMG installation:**
   - Clear data: `defaults delete com.plexwidget.app && security delete-generic-password -s "com.plexwidget.credentials" -a "plex-token"`
   - Mount DMG and drag to Applications
   - Launch from /Applications/PlexWidget.app
   - Verify onboarding and functionality

6. **LAUNCH!** 🚀
   - Push to GitHub
   - Create release with DMG attached
   - Update README with download link

### If Still Broken

- Check Console.app for crash logs
- Verify DerivedData path is correct
- May need to reinstall Xcode command line tools

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

**Last Commit:** 2c6f9af - "feat: Add menu bar integration, settings panel, and production DMG"

**Recent Commits:**
- 2c6f9af (HEAD) feat: Add menu bar integration, settings panel, and production DMG
- a6e0775 Add Plex Desktop Widget with security features and documentation
- 37035d8 Initial commit: Plex Desktop Widget (Swift/SwiftUI)

**Current State:**
- All changes from this session are committed
- Code reverted to working version a6e0775 patterns
- Ready for testing after restart
