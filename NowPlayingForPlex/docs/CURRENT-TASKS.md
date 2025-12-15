# NowPlaying for Plex - Current Tasks

**Last Updated:** 2025-12-15

## Session Status: v1.2.0 RELEASED

### What Was Accomplished This Session

**Mini Mode Enhancements:**
1. Added scrolling text for long titles in mini mode
2. Added scrolling text for long artist/album names in mini mode
3. Fixed "Overlay" label truncation in settings (reduced padding)
4. Reorganized settings footer - Change Server now under IP, Quit button on right

**Version & Release:**
- Bumped version to 1.2.0 (build 3)
- Created DMG installer
- Pushed all changes to GitHub
- Release notes prepared for v1.2.0

**Files Modified This Session:**
- `NowPlayingForPlex/NowPlayingView.swift` - Added subtitle scrolling, state variables
- `NowPlayingForPlex/SettingsView.swift` - Fixed padding, reorganized footer layout
- `NowPlayingForPlex/Info.plist` - Version bump to 1.2

**Commits This Session:**
- `24c7854` - feat: Add scrolling text for mini mode and improve settings layout
- `ac068c7` - chore: Bump version to 1.2.0

---

## Current State: READY FOR RELEASE

### What's Working
- Mini layout mode with scrolling text
- All three layouts: Side, Overlay, Mini
- Dynamic window resizing when switching layouts
- Settings panel fully functional
- Universal binary (Intel + Apple Silicon)
- DMG installer ready: `NowPlaying-for-Plex.dmg`

### Version History
| Version | Features |
|---------|----------|
| v1.0.0 | Initial release |
| v1.1.0 | Server reset feature |
| v1.2.0 | Mini mode with scrolling text |

---

## Active Tasks

### GitHub Release v1.2.0
**Status:** READY TO PUBLISH

Release notes prepared:
```
# NowPlaying for Plex v1.2.0

## What's New

### Mini Mode
A new compact layout (320x100) perfect for keeping in the corner of your screen.
- 70x70 album art
- Combined artist/album line
- Scrolling text for long titles and artist names

### Improvements
- Fixed "Overlay" label truncation in settings
- Improved settings layout

## Download
Universal binary for Apple Silicon and Intel Macs.
```

---

## Pending Tasks

### Mac App Store Preparation
**Status:** WAITING ON D-U-N-S NUMBER
**Blocker:** Apple Developer Program enrollment requires D-U-N-S number

---

## Important Context

### Bundle Identifier
`com.nowplayingforplex.app`

### Build Commands
```bash
cd /Volumes/LIME2/Work/Development/nowplaying-for-plex/NowPlayingForPlex

# Build
./build.sh

# Create DMG
./create-dmg.sh

# Run from build
open "build/NowPlaying for Plex.app"

# Run from Applications
open "/Applications/NowPlaying for Plex.app"
```

### Key Technical Notes
- Scrolling text uses `shouldScrollTitle` and `shouldScrollSubtitle` state variables
- Subtitle scrolling speed is slightly slower (40.0) than title (50.0)
- Settings panel width is 280px with 24px padding
- Mini mode dimensions: 320x100 window, 70x70 album art

---

**End of Session: 2025-12-15**
**Status: v1.2.0 ready for GitHub release**
