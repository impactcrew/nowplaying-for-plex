#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/plex-packaging-test.XXXXXX")"
test_dir="$(cd "$test_dir" && pwd -P)"
trap 'rm -rf "$test_dir"' EXIT

export PLEX_PACKAGING_TEST_ROOT="$test_dir"
export PATH="$test_dir/bin:$PATH"
mkdir -p "$test_dir/bin" "$test_dir/build/NowPlaying for Plex.app"

for tool in hdiutil ditto convert SetFile chflags defaults killall sleep sync sips DeRez Rez osascript codesign xcrun spctl lipo; do
    ln -s "$project_dir/NowPlayingForPlexTests/packaging-tool.sh" "$test_dir/bin/$tool"
done

run_package() {
    (
        cd "$test_dir"
        bash "$project_dir/create-dmg.sh" "${1:---local}" "$test_dir/build/NowPlaying for Plex.app" "$test_dir/preview.dmg"
    )
}

fail() {
    printf '%s\n' "$1" >&2
    cat "$PLEX_PACKAGING_TEST_LOG" >&2
    exit 1
}

export PLEX_PACKAGING_TEST_LOG="$test_dir/success.log"
if ! run_package; then
    fail "Packaging a local app should succeed."
fi
[[ -f "$test_dir/preview.dmg" ]] || fail "The completed image was not published."
if compgen -G "$test_dir/.plex-dmg.*" > /dev/null; then
    fail "Staging was not removed after success."
fi

export PLEX_PACKAGING_TEST_LOG="$test_dir/failure.log"
export PLEX_PACKAGING_TEST_FAIL_FINDER=1
printf '%s\n' "previous image" > "$test_dir/preview.dmg"
if run_package; then
    fail "A failure after attachment should fail packaging."
fi
[[ "$(cat "$test_dir/preview.dmg")" == "previous image" ]] || fail "A failed run replaced the previous image."
if compgen -G "$test_dir/.plex-dmg.*" > /dev/null; then
    fail "Staging was not removed after failure."
fi

for log in "$test_dir/success.log" "$test_dir/failure.log"; do
    PLEX_PACKAGING_TEST_LOG="$log"
    if grep -Eq '^(defaults|killall) |^hdiutil detach .* -force' "$log"; then
        fail "Packaging changed global state or detached an unrelated device."
    fi
    attached="$(sed -n 's/^hdiutil attach .* -mountpoint \(.*\)$/\1/p' "$log")"
    detached="$(sed -n 's/^hdiutil detach \(.*\)$/\1/p' "$log")"
    [[ "$attached" == "$test_dir/"*"/mount" ]] || fail "The attachment was outside the private staging directory."
    [[ "$detached" == "/dev/disk947s1" ]] || fail "Packaging did not detach exactly what it attached."
done

export PLEX_PACKAGING_TEST_LOG="$test_dir/partial-attachment.log"
export PLEX_PACKAGING_TEST_FAIL_ATTACH=1
unset PLEX_PACKAGING_TEST_FAIL_FINDER
if run_package; then
    fail "A partial attachment should fail packaging."
fi
attach_path="$(sed -n 's/^hdiutil attach .* -mountpoint \(.*\)$/\1/p' "$PLEX_PACKAGING_TEST_LOG")"
grep -Fx "hdiutil detach $attach_path" "$PLEX_PACKAGING_TEST_LOG" > /dev/null || fail "Partial attachment was not cleaned up by its private mount path."
[[ "$(cat "$test_dir/preview.dmg")" == "previous image" ]] || fail "Partial attachment replaced the previous image."
unset PLEX_PACKAGING_TEST_FAIL_ATTACH

bundle_contents="$test_dir/build/NowPlaying for Plex.app/Contents"
mkdir -p "$bundle_contents/Resources" "$bundle_contents/MacOS"
info="$bundle_contents/Info.plist"
expected_version="$(awk -F ' *= *' '$1 == "MARKETING_VERSION" {print $2}' "$project_dir/ReleaseVersion.xcconfig")"
expected_build="$(awk -F ' *= *' '$1 == "CURRENT_PROJECT_VERSION" {print $2}' "$project_dir/ReleaseVersion.xcconfig")"
plutil -create xml1 "$info"
plutil -insert CFBundleShortVersionString -string "$expected_version" "$info"
plutil -insert CFBundleVersion -string "$expected_build" "$info"
plutil -insert CFBundleExecutable -string "PlexWidget" "$info"
plutil -create xml1 "$bundle_contents/Resources/PrivacyInfo.xcprivacy"
touch "$bundle_contents/MacOS/PlexWidget"
export PLEX_RELEASE_SIGNING_IDENTITY="Test signing identity"
export PLEX_RELEASE_NOTARY_PROFILE="test-notary-profile"
export PLEX_PACKAGING_TEST_LOG="$test_dir/unsigned-app.log"
if run_package --release; then
    fail "Release packaging should reject an app with an invalid signature."
fi
grep -q '^codesign --verify' "$PLEX_PACKAGING_TEST_LOG" || fail "Release packaging did not check the input signature."
if grep -q '^hdiutil ' "$PLEX_PACKAGING_TEST_LOG"; then
    fail "Release packaging touched disk images before verifying the app."
fi

export PLEX_PACKAGING_TEST_SIGNED_APP=1
export PLEX_PACKAGING_TEST_FAIL_NOTARIZATION=1
export PLEX_PACKAGING_TEST_LOG="$test_dir/failed-notarization.log"
if run_package --release; then
    fail "Release packaging should fail when notarization is rejected."
fi
[[ "$(cat "$test_dir/preview.dmg")" == "previous image" ]] || fail "Failed notarization replaced the previous image."
if grep -q '^xcrun stapler ' "$PLEX_PACKAGING_TEST_LOG"; then
    fail "Release packaging tried to staple a rejected image."
fi

unset PLEX_PACKAGING_TEST_FAIL_NOTARIZATION
export PLEX_PACKAGING_TEST_LOG="$test_dir/release.log"
run_package --release || fail "A verified and stapled image should be published."
[[ "$(cat "$test_dir/preview.dmg")" == "signed and stapled release" ]] || fail "The published image was different from the verified image."

printf '%s\n' "Packaging, cleanup and release gating passed."
