# Clip the settings menu material

## Scope

Follow-up to the approved macOS border repair. The user supplied a screenshot showing lighter square corners outside the rounded menu background.

## Evidence and change

SettingsView applies a SwiftUI shape clip around a native behind-window material, but VisualEffectView never sets NSVisualEffectView.maskImage. The AppKit SDK documents maskImage as the alpha mask for the generated material, with capInsets for stretching. Add an optional native mask to VisualEffectView and supply a stretchable image with square top corners and 20-point bottom corners only for the settings background.

## Verification

Build with Xcode 27.1 outside the sandbox, review the diff, verify the signature, install with a backup, and restart the app. User visual confirmation remains required because desktop-control tools are unavailable. Preserve the existing menu shape, contents, and player shadow fix.

## Status

Implemented and installed. Release arm64 build passed in Xcode 27.1. Code and security reviewers reported no findings, including native mask orientation and stretching. The installed app passes signature verification, matches the built executable, and relaunched successfully. The previous app is backed up in dev/scratch/2026-10-23-settings-menu-corners/installed-app-backup.zip. Visual confirmation of the running menu remains pending. The user is considering a future native glass menu appearance; no redesign has been implemented.
