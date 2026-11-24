#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")" && pwd)"
app_name="NowPlaying for Plex.app"
volume_name="NowPlaying for Plex"

usage() {
    printf '%s\n' "Usage: $0 --local|--test|--release <app bundle> <output.dmg>" >&2
    exit 2
}

[[ $# == 3 ]] || usage
mode="$1"
[[ "$mode" == --local || "$mode" == --test || "$mode" == --release ]] || usage
[[ -d "$2" && "$2" == *.app && "$3" == *.dmg ]] || usage

source_app="$(cd "$(dirname "$2")" && pwd -P)/$(basename "$2")"
output_dir="$(cd "$(dirname "$3")" && pwd -P)"
output="$output_dir/$(basename "$3")"
if [[ -d "$output" ]]; then
    printf 'The output path is a directory: %s\n' "$output" >&2
    exit 2
fi

developer_id_requirement='anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.13] exists'
if [[ "$mode" != --local ]]; then
    bash "$project_dir/check-bundle.sh" "$source_app"
fi
if [[ "$mode" == --test && ! -s "$source_app/Contents/_CodeSignature/CodeResources" ]]; then
    printf '%s\n' 'Build the signed app bundle in Xcode before packaging a test DMG.' >&2
    exit 1
fi
if [[ "$mode" == --release ]]; then
    : "${PLEX_RELEASE_SIGNING_IDENTITY:?Set PLEX_RELEASE_SIGNING_IDENTITY to the Developer ID Application identity.}"
    : "${PLEX_RELEASE_NOTARY_PROFILE:?Set PLEX_RELEASE_NOTARY_PROFILE to the saved Apple notarization profile.}"
    codesign --verify --deep --strict --test-requirement "$developer_id_requirement" "$source_app"
fi

stage="$(mktemp -d "$output_dir/.plex-dmg.XXXXXX")"
mount_dir="$stage/mount"
attached_device=""

cleanup() {
    status=$?
    trap - EXIT
    if [[ -n "$attached_device" || -L "$mount_dir/Applications" ]]; then
        if ! hdiutil detach "${attached_device:-$mount_dir}"; then
            printf 'The image is still mounted at %s. The staging directory was kept.\n' "$mount_dir" >&2
            exit 1
        fi
    fi
    rm -rf "$stage"
    exit "$status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

attach_image() {
    local image="$1"
    local index=0
    local entity mounted_path device
    shift

    hdiutil attach "$image" "$@" -plist -nobrowse -noautoopen -mountpoint "$mount_dir" > "$stage/attachment.plist"
    while plutil -extract "system-entities.$index" xml1 -o - "$stage/attachment.plist" > /dev/null 2>&1; do
        entity="system-entities.$index"
        if mounted_path="$(plutil -extract "$entity.mount-point" raw -o - "$stage/attachment.plist" 2>/dev/null)" &&
           [[ "$mounted_path" == "$mount_dir" ]]; then
            device="$(plutil -extract "$entity.dev-entry" raw -o - "$stage/attachment.plist")"
            if [[ "$device" =~ ^/dev/disk[0-9]+(s[0-9]+)*$ ]]; then
                attached_device="$device"
                return
            fi
        fi
        index=$((index + 1))
    done

    printf 'Could not identify the newly mounted disk image.\n' >&2
    return 1
}

detach_image() {
    hdiutil detach "$attached_device"
    attached_device=""
}

image_contents="$stage/contents"
writable_image="$stage/layout.dmg"
ready_image="$stage/output/$(basename "$output")"

mkdir "$image_contents" "$mount_dir" "$stage/output"
mkdir "$image_contents/.background"
ditto --noextattr --norsrc "$source_app" "$image_contents/$app_name"
ln -s /Applications "$image_contents/Applications"
cp "$project_dir/dmg-layout/background.png" "$image_contents/.background/background.png"

if [[ "$mode" == --test ]]; then
    # Preserve the original Finder layout without opening Finder or mounting an image.
    cp "$project_dir/dmg-layout/FinderLayout.dsstore" "$image_contents/.DS_Store"
    cp "$project_dir/dmg-volume-icon.icns" "$image_contents/.VolumeIcon.icns"
    chflags hidden "$image_contents/.background" "$image_contents/.VolumeIcon.icns"
    SetFile -a C "$image_contents"
    hdiutil makehybrid -hfs -hfs-volume-name "$volume_name" \
        -hfs-openfolder "$image_contents" -o "$writable_image" "$image_contents"
else
    hdiutil create -volname "$volume_name" -srcfolder "$image_contents" -format UDRW "$writable_image"
    attach_image "$writable_image"

    ditto "$project_dir/dmg-volume-icon.icns" "$mount_dir/.VolumeIcon.icns"
    chflags hidden "$mount_dir/.background" "$mount_dir/.VolumeIcon.icns"
    SetFile -a C "$mount_dir"
    osascript "$project_dir/layout-dmg.applescript" "$mount_dir" "$app_name"
    xattr -cr "$mount_dir/$app_name"
    detach_image
fi
hdiutil convert "$writable_image" -format UDZO -imagekey zlib-level=9 -o "$ready_image"

if [[ "$mode" != --test ]]; then
    # Work on a copy because sips adds a resource fork to the icon file.
    ditto "$project_dir/dmg-file-icon.icns" "$stage/file-icon.icns"
    sips -i "$stage/file-icon.icns"
    DeRez -only icns "$stage/file-icon.icns" > "$stage/file-icon.rsrc"
    Rez -append "$stage/file-icon.rsrc" -o "$ready_image"
    SetFile -a C "$ready_image"
fi

if [[ "$mode" == --release ]]; then
    attach_image "$ready_image" -readonly
    codesign --verify --deep --strict --test-requirement "$developer_id_requirement" "$mount_dir/$app_name"
    detach_image

    codesign --sign "$PLEX_RELEASE_SIGNING_IDENTITY" --timestamp --identifier com.nowplayingforplex.app.dmg "$ready_image"
    codesign --verify --strict --test-requirement "$developer_id_requirement" "$ready_image"
    xcrun notarytool submit "$ready_image" --keychain-profile "$PLEX_RELEASE_NOTARY_PROFILE" --wait --output-format json > "$stage/notarization.json"
    notary_status="$(plutil -extract status raw -o - "$stage/notarization.json")"
    if [[ "$notary_status" != Accepted ]]; then
        submission="$(plutil -extract id raw -o - "$stage/notarization.json")"
        printf 'Apple notarization returned %s for submission %s.\n' "$notary_status" "$submission" >&2
        exit 1
    fi
    xcrun stapler staple "$ready_image"
    xcrun stapler validate "$ready_image"
    spctl --assess --type open --context context:primary-signature "$ready_image"
fi

hdiutil verify "$ready_image"
mv -f "$ready_image" "$output"
printf 'Installer: %s\n' "$output"
