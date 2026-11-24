# Current tasks

Last updated 2026-11-24.

## Next

- [ ] Confirm a passing GitHub Actions macOS run for the release revision.
- [ ] Open the exact signed DMG on a clean Mac with Gatekeeper enabled. Confirm the Finder layout, first-time Plex setup and live music display, widget and setup window dragging, Reset Position, Tab and Escape, and the orange On and grey Off launch-at-login switch. Check display recovery by unplugging a monitor. Runtime checks on Intel and macOS 13 are still open.
- [ ] Upgrade a working public v1.3.0 install with the final signed app and confirm Plex stays signed in.
- [ ] Check whether the removed integration still appears in the repository contributors list. This is a separate, older task.

## Where things stand

- All 12 review fixes and the build 4 feedback are implemented. Local branch `fix/widget-window-border` contains the app changes at `91db731` and the installer changes at `9c9b471`. No push or release took place.
- The current release candidate is **1.3.1 build 7** at app revision `7d1b55a`. It uses the approved five-bar Amber app icon, three-bar menu bar icon and Mist blue Record sleeve installer with the curved Record arc. The [archive](../NowPlayingForPlex/build/1.3.1-7/NowPlaying-for-Plex.xcarchive) passed the version, privacy manifest, and Intel and Apple Silicon checks. All 23 standalone app tests passed, along with the menu bar rendering check and the packaging fixtures.
- Zeal signed, notarized and stapled the [build 7 app](../NowPlayingForPlex/build/1.3.1-7/NowPlaying%20for%20Plex.app). All seven permissions matched on both architectures. Zeal also signed, notarized and stapled the [build 7 installer](../NowPlayingForPlex/build/1.3.1-7/NowPlaying-for-Plex.dmg) and confirmed Gatekeeper acceptance. The disk checksum passed. Signing preserved the disk volume exactly, including the signed app, the Record sleeve artwork, the bound Finder background reference and the Applications shortcut. The SHA-256 is `960090811cbbffd485e60de433bae5d04864572a3da774b2383c5651b48600f5`.
- Build 6 introduced the Reset Position placement beside Layout Style. Its signed installer is retained as an earlier candidate.
- Xcode compiled the app-hosted test bundle with signing disabled. The local run stopped before executing tests because the session could not connect to the macOS test runner service. The GitHub Actions run remains pending.
- The [1.3.1 release notes](active/hostile-repo-review/v1.3.1-release-notes.md) are prepared for the GitHub release.
- Zeal signed, notarized and stapled [NowPlaying for Plex.app](../NowPlayingForPlex/build/1.3.1-6/NowPlaying%20for%20Plex.app) with `NowPlayingForPlex.entitlements`. All seven permissions matched on both architectures, and the app passed Zeal's Gatekeeper check.
- Zeal signed and notarized the [final NowPlaying-for-Plex.dmg](../NowPlayingForPlex/build/1.3.1-6/NowPlaying-for-Plex.dmg), stapled the ticket and confirmed Gatekeeper acceptance. Disk-image verification and offline readback passed after signing. The app, notarization ticket, artwork, volume icon and Applications link match their sources. The SHA-256 is `2007155ed050818636c160f86509d40491a2d0d824ca9d19e0286fdff4cc1ada`.
- The offline image builder adds Finder metadata inside app bundles. The build 7 installer binds the Finder background reference to the packaged image and clears metadata only inside the app. The packaging script stages the signed app with its bytes and modes intact and omits extended attributes. The fixtures cover metadata-free staging and rejection of an invalid packaged app.
- [NowPlaying for Plex 1.3.0 build 5](active/hostile-repo-review/testing/NowPlaying-for-Plex-1.3.0-5-test.dmg) remains available as the ad hoc test installer. Security framework checks confirmed its signatures, sandbox and outgoing network entitlements. The disk-image checksum and offline readback confirmed the app, original background, Finder layout and volume icon. Interactive installer checks are tracked above for the final signed DMG.
- The installed app sampled in this session was 1.3.0 build 5. Over 60 seconds it averaged 0.008% of one core, peaked at 0.022% in a one-second interval, and held about 32 MiB of memory. Playback state was unverified.

## Decisions to keep

- Preserve the legacy Keychain item and its server address as a pair. The new connection has a separate Keychain record and address hint. Keychain read failures offer a retry. Build 4 omitted the sandbox entitlements and is superseded.
- Users upgrading directly from v1.0.0 need to reconnect. The README and release notes describe that step. Playback Source selects among music sessions. Shows and films are ignored, so Automatic is sufficient for the user's setup.
- Use the signed app with `NowPlayingForPlex/create-dmg.sh --test` for local images. It uses the approved layout and artwork in `NowPlayingForPlex/dmg-layout/`. The release mode retains the Developer ID and notarization checks.
- Keep the approved settings panel dark with 60 percent charcoal fill and 40 percent direct desktop visibility. Use square top corners, 20-point bottom corners, orange selection gradients and compact Change Server spacing. Keep the system window shadow disabled because the player draws its own.
- The existing `AnyShape` Sendable warning remains. Earlier design checks are in `dev/active/glass-settings-menu/`, and the original app backup is in `dev/completed/widget-window-border/installed-app-backup.zip`.

See [review and repair records](active/hostile-repo-review/PLAN.md) for the full history.

The [release readiness check](active/hostile-repo-review/release-readiness.html) records the public version overlap, upgrade findings, and remaining release checks.
