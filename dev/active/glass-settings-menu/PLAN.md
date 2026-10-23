# Native glass settings menu

## Approved direction

The user approved one native glass settings panel, familiar controls and layout, and restrained orange selection highlights. Implement this direction without another approval gate.

## Work

Obtain the native design specification, then update the menu presentation using system Liquid Glass on macOS 26 and later. Retain the existing masked material on supported older systems because the project targets macOS 13. Use readable semantic foreground colors and quieter control backgrounds. Preserve all settings bindings, actions, and the fixed player window border.

## Verification

Use the installed Xcode 27.1 for a Release build. Review the code and security implications. Verify the installed app signature and executable, back up the previous build, and restart the app. Check available programmatic rendering and accessibility behavior; record visual checks that cannot be performed with available tools. Do not publish or push.

## Status

Implemented and installed. Release arm64 build passed with Xcode 27.1; the existing unrelated AnyShape Sendable warning remains. Code and security reviews reported no findings. Installation backed up the previous app, verified the installed code signature and matching executable SHA-256, and relaunched successfully. Desktop-control tools are unavailable, so visual verification of light/dark contrast, glass corners, expanded Glow Colour layout, and accessibility appearances remains pending. No AppDelegate sizing change was made: hosting view sizing constraints already update window bounds, and a clipping fault was not demonstrated. Native implementation resides in SettingsView.swift. No publication or push.
