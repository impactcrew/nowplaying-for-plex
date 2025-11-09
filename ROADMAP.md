# Plex Desktop Widget - Roadmap

Internal planning document for future features and improvements.

## v1.1 - Planned Features

### Seamless Track Transitions
**Priority:** High
**Status:** Planned

Currently, the widget displays a brief flicker (blank/no track info) for a split second when transitioning between tracks in continuous playback (DJ mixes, albums with no gaps, etc.).

**Goal:** Eliminate this display gap by:
- Pre-loading next track metadata before transition
- Implementing smooth fade/crossfade animation
- Maintaining displayed track info until new track is fully loaded

**Technical Approach:**
- Monitor playback position and pre-fetch next track data
- Implement buffered state management for track transitions
- Add animation layer for smooth visual transitions

### Mini Mode
**Priority:** Medium
**Status:** Planned

Add a compact "mini" display mode for users who want a smaller on-screen presence.

**Requirements:**
- Smaller footprint (reduced size)
- Essential info only (track name, artist, album art)
- Toggleable from settings
- Maintain glassmorphic aesthetic
- Responsive to screen size constraints

**Design Considerations:**
- Minimum viable size while maintaining readability
- Optional: Hover to expand for full controls
- Position memory (remember last placement)

## Future Considerations

These items are under consideration but not yet scheduled:

- **Playlist support** - Display current playlist and allow navigation
- **Lyrics integration** - Show synchronized lyrics if available
- **Scrobbling** - Last.fm/ListenBrainz integration
- **Keyboard shortcuts** - Global hotkeys for playback control
- **Multiple server support** - Quick switching between Plex servers
- **Enhanced animations** - More polished UI transitions and micro-interactions

## Completed Features

### v1.0 - Initial Release
- ✅ Real-time now playing display
- ✅ Album artwork with glassmorphic overlay
- ✅ Theme support (Light/Dark)
- ✅ Layout options (Side/Overlay)
- ✅ Album art shape options (Square/Circular)
- ✅ Customizable glow effects
- ✅ Menu bar integration for settings
- ✅ Secure Keychain credential storage
- ✅ Onboarding flow
