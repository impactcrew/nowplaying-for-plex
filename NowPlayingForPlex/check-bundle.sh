#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")" && pwd)"
if [[ $# != 1 ]]; then
    printf 'Usage: %s <app bundle>\n' "$0" >&2
    exit 2
fi

bundle="$1"
info="$bundle/Contents/Info.plist"
privacy="$bundle/Contents/Resources/PrivacyInfo.xcprivacy"
expected_version="$(awk -F ' *= *' '$1 == "MARKETING_VERSION" {print $2}' "$project_dir/ReleaseVersion.xcconfig")"
expected_build="$(awk -F ' *= *' '$1 == "CURRENT_PROJECT_VERSION" {print $2}' "$project_dir/ReleaseVersion.xcconfig")"

check_value() {
    actual="$(plutil -extract "$1" raw -o - "$info")"
    if [[ "$actual" != "$2" ]]; then
        printf '%s is %s, expected %s.\n' "$1" "$actual" "$2" >&2
        exit 1
    fi
}

[[ -n "$expected_version" && -n "$expected_build" ]]
plutil -lint "$info" "$privacy"
check_value CFBundleShortVersionString "$expected_version"
check_value CFBundleVersion "$expected_build"

executable="$(plutil -extract CFBundleExecutable raw -o - "$info")"
if ! lipo -verify_arch arm64 x86_64 "$bundle/Contents/MacOS/$executable"; then
    printf 'Expected both arm64 and x86_64 in %s.\n' "$executable" >&2
    exit 1
fi

printf 'Verified bundle metadata and universal executable: %s (%s)\n' "$expected_version" "$expected_build"
