# Current tasks

Last updated 2026-11-24.

## Next

- [ ] Test build 5 on the Mac. Confirm the existing Plex login survives, the widget and setup window drag, and Finder shows the approved DMG layout. Include Tab and Escape in the settings panel and confirm the orange On and grey Off launch-at-login switch.
- [ ] Confirm the hosted macOS checks for 1.3.1 build 6 and verify the signed, notarized release DMG on a clean Mac. Test Plex sign-in after upgrading from public v1.3.0. The README tells users upgrading directly from v1.0.0 to reconnect.
- [ ] Check whether the removed integration still appears in the repository contributors list. This is a separate, older task.

## Where things stand

- All 12 review fixes and the build 4 feedback are implemented. Local branch `fix/widget-window-border` contains the app changes at `91db731` and the installer changes at `9c9b471`. No push or release took place.
- The current release candidate is **1.3.1 build 6** and includes the Reset Position move from `94c162c`. Xcode 27.2 built the [unsigned app](../NowPlayingForPlex/build/1.3.1-6/PlexWidget.app) and [unsigned archive](../NowPlayingForPlex/build/1.3.1-6/NowPlaying-for-Plex.xcarchive). The archived app passed the version, privacy manifest, and Intel and Apple Silicon checks. All 23 standalone app tests and the packaging tests passed.
- Xcode compiled the app-hosted test bundle with signing disabled. The local run stopped before executing tests because the session could not connect to the macOS test runner service. The GitHub Actions run remains pending.
- The [1.3.1 release notes](active/hostile-repo-review/v1.3.1-release-notes.md) are prepared for the GitHub release.
- [NowPlaying for Plex 1.3.0 build 5](active/hostile-repo-review/testing/NowPlaying-for-Plex-1.3.0-5-test.dmg) remains available as the ad hoc test installer. Security framework checks confirmed its signatures, sandbox and outgoing network entitlements. The disk-image checksum and offline readback confirmed the app, original background, Finder layout and volume icon. The session could not mount the image, so installation and live checks are still open.

## Decisions to keep

- Preserve the legacy Keychain item and its server address as a pair. The new connection has a separate Keychain record and address hint. Keychain read failures offer a retry. Build 4 omitted the sandbox entitlements and is superseded.
- Use the signed app with `NowPlayingForPlex/create-dmg.sh --test` for local images. It uses the approved layout and artwork in `NowPlayingForPlex/dmg-layout/`. The release mode retains the Developer ID and notarization checks.
- Keep the approved settings panel dark with 60 percent charcoal fill and 40 percent direct desktop visibility. Use square top corners, 20-point bottom corners, orange selection gradients and compact Change Server spacing. Keep the system window shadow disabled because the player draws its own.
- The existing `AnyShape` Sendable warning remains. Earlier design checks are in `dev/active/glass-settings-menu/`, and the original app backup is in `dev/completed/widget-window-border/installed-app-backup.zip`.

See [review and repair records](active/hostile-repo-review/PLAN.md) for the full history.

The [release readiness check](active/hostile-repo-review/release-readiness.html) records the public version overlap, upgrade findings, and remaining release checks.
