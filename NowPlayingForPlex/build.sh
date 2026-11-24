#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")" && pwd)"
build_dir="$project_dir/build"
app_name="NowPlaying for Plex"
app_path="$build_dir/$app_name.app"

xcodebuild \
    -project "$project_dir/NowPlayingForPlex.xcodeproj" \
    -scheme PlexWidget \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$build_dir/DerivedData" \
    "CONFIGURATION_BUILD_DIR=$build_dir" \
    "PRODUCT_NAME=$app_name" \
    "ARCHS=arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY=- \
    build

bash "$project_dir/check-bundle.sh" "$app_path"
printf 'Local app: %s\n' "$app_path"
