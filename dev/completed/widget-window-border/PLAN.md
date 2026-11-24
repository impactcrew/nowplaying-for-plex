# Remove the widget window outline

## Evidence

The supplied screenshot shows an outline surrounding the transparent padding outside the player. The local operating system reports macOS 27.0.1. The main widget uses a transparent, borderless window but explicitly enables its system shadow in NowPlayingForPlex/NowPlayingForPlex/NowPlayingForPlexApp.swift. NowPlayingView.swift separately supplies the player shadows and optional glow. The system shadow is the leading cause; visual comparison is required to confirm it.

## Proposed change

Set the main widget window hasShadow property to false. Classify this as a window configuration change, verified by a build and visual checklist. Keep the player appearance and existing macOS 13 deployment target. One sequential implementation group affects one production file.

## Verification

Build using the installed Xcode directly without changing the global developer directory. Compare the running widget before and after the change on macOS 27.0.1. Confirm the outer outline disappears, the player shadows remain, dragging works, and side, overlay, and mini layouts display correctly with glow enabled and disabled. Do not claim visual verification until performed. No automated test target is configured in the project.

## Scope

Do not migrate the old documentation layout, install or publish a release, or commit changes as part of preparing this plan. Replacing the installed application requires completing and verifying the build first.

## Status

Approved and implemented. Disabled the main widget system shadow. Release arm64 build passed with Xcode 27.1 outside the sandbox; the sandbox blocked compiler plugins. Code and security reviews reported no findings. The installed app was backed up in the session scratch folder, replaced, cleared of leftover FinderInfo metadata, and relaunched successfully. Installed signature verification passed, and its executable SHA-256 matches the built executable. The user confirmed the border is fixed. Other layout and glow combinations were not separately exercised. No release was published.
