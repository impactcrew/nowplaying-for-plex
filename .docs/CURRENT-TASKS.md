# Plex Desktop Widget - Current Tasks

**Last Updated:** 2025-11-10

## Active Tasks

### Production Release Preparation
**Status:** Ready for DMG Creation
**Priority:** HIGH

**Current State:**
App is fully functional and crash-free after fixing the lazy initialization issue.

**Next Steps:**
1. Create production DMG with working build
2. Test DMG installation on clean system
3. Create GitHub release
4. Publish to App Store (future)

---

## Completed Tasks

### Fixed App Crash on Launch
**Status:** ✅ RESOLVED
**Date Completed:** 2025-11-10
**Commit:** 2b86e73

**The Problem:**
App crashed with SIGSEGV (EXC_BAD_ACCESS at 0x20) during startup when accessing WidgetSettings.

**Root Cause:**
The crash occurred because `WidgetSettings.shared` was being eagerly initialized in AppDelegate:
```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var settings = WidgetSettings.shared  // ❌ Accessed @AppStorage too early
```

Since `WidgetSettings` uses `@AppStorage` property wrappers that access UserDefaults, this was happening before the app lifecycle was fully initialized, causing memory corruption.

**The Fix:**
Changed to lazy initialization in PlexWidgetApp.swift:30:
```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    lazy var settings = WidgetSettings.shared  // ✅ Delays initialization
```

This ensures `WidgetSettings` and its `@AppStorage` properties are only created when first accessed, after the app has fully initialized.

**Verified:**
- App launches successfully without crashes
- Onboarding flow works correctly
- Menu bar icon appears
- Settings panel accessible
- All features functional

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
