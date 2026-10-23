# NowPlaying for Plex - Settings menu

**Approved:** 2026-10-23
**Stack:** Native macOS SwiftUI
**Files:** ../nowplaying-for-plex/NowPlayingForPlex/NowPlayingForPlex/SettingsView.swift
**Screenshot:** No final capture; accepted appearance was confirmed by the user.

## Stance
A dark control panel beside the album sleeve.

## References
The app's original menu and the user's screenshot feedback. Preserve its dark character, orange selection gradients and compact footer. Pale system-adaptive glass was rejected.

## Tokens
- Font: native SF Pro via SwiftUI, 13 pt medium labels and 11 pt secondary text.
- Surface: #0D0D0D at 60 percent opacity, 40 percent direct desktop visibility, no native blur material.
- Selection: #E5A00D to #CC7B02 gradient with black text.
- Text: semantic primary/secondary under forced dark appearance.
- Radius and spacing: square top, 20 pt bottom corners, 280 pt width, 24 pt inset/section spacing, 4 pt address-to-action spacing.
- Launch switch: orange gradient On, grey Off, white knob, native accessibility representation.

## What made it land
The user said "looks great" after the blur material was removed and desktop visibility became direct. The remaining requested correction restored the original orange switch state.

## Reusable lesson
For a desktop-transparent utility panel, a tinted native material plus an alpha overlay can still look opaque. Use a single translucent fill when visible desktop detail is the goal. Preserve the original control palette and compact spacing during material updates.
