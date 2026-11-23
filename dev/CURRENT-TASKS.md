# Current tasks

Last updated 2026-11-23.

## Next

- [ ] Test build 5 on the Mac. Confirm the existing Plex login survives, the widget and setup window drag, and Finder shows the approved DMG layout. Include Tab and Escape in the settings panel and confirm the orange On and grey Off launch-at-login switch.
- [ ] Before a public release, confirm the hosted macOS checks and verify the signed, notarized release DMG on a clean Mac.
- [ ] Check whether the removed integration still appears in the repository contributors list. This is a separate, older task.

## Where things stand

- All 12 review fixes and the build 4 feedback are implemented. Local branch `fix/widget-window-border` contains the app changes at `91db731` and the installer changes at `9c9b471`. No push or release took place.
- The current artifact is [NowPlaying for Plex 1.3.0 build 5](active/hostile-repo-review/testing/NowPlaying-for-Plex-1.3.0-5-test.dmg), signed ad hoc for local testing. It was selected in Finder. The session could not mount the image, so the actual install and live checks are still open.
- The 23 standalone XCTest cases and packaging regression suite passed. Xcode 27.2 built both architectures. Security framework checks confirmed the signatures, sandbox and outgoing network entitlements. The DMG checksum and offline readback confirmed the exact app, original background, Finder layout and volume icon.

## Decisions to keep

- Preserve the legacy Keychain item and its server address as a pair. The new connection has a separate Keychain record and address hint. Keychain read failures offer a retry. Build 4 omitted the sandbox entitlements and is superseded.
- Use the signed app with `NowPlayingForPlex/create-dmg.sh --test` for local images. It uses the approved layout and artwork in `NowPlayingForPlex/dmg-layout/`. The release mode retains the Developer ID and notarization checks.
- Keep the approved settings panel dark with 60 percent charcoal fill and 40 percent direct desktop visibility. Use square top corners, 20-point bottom corners, orange selection gradients and compact Change Server spacing. Keep the system window shadow disabled because the player draws its own.
- The existing `AnyShape` Sendable warning remains. Earlier design checks are in `dev/active/glass-settings-menu/`, and the original app backup is in `dev/completed/widget-window-border/installed-app-backup.zip`.

See [review and repair records](active/hostile-repo-review/PLAN.md) for the full history.
