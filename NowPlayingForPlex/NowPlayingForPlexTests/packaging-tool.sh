#!/bin/bash
set -eu

tool="${0##*/}"
printf '%s %s\n' "$tool" "$*" >> "$PLEX_PACKAGING_TEST_LOG"

case "$tool" in
    hdiutil)
        case "$1" in
            create)
                rm -f "$PLEX_PACKAGING_TEST_ROOT/added-finder-metadata"
                touch "${@: -1}"
                ;;
            makehybrid)
                contents="${@: -1}"
                [[ -s "$contents/.background/background.png" && -s "$contents/.DS_Store" &&
                    -s "$contents/.VolumeIcon.icns" && -d "$contents/NowPlaying for Plex.app" ]] || exit 1
                [[ "$(readlink "$contents/Applications")" == /Applications ]] || exit 1
                signature="NowPlaying for Plex.app/Contents/_CodeSignature/CodeResources"
                cmp "$PLEX_PACKAGING_TEST_ROOT/build/$signature" "$contents/$signature" || exit 1
                [[ -z "$(/usr/bin/xattr "$contents/$signature")" ]] || exit 1
                touch "${@: -2:1}"
                ;;
            attach)
                mount_dir="${@: -1}"
                [[ "$mount_dir" == "$PLEX_PACKAGING_TEST_ROOT/"*"/mount" ]] || exit 1
                ln -s /Applications "$mount_dir/Applications"
                printf '%s\n' "$mount_dir" > "$PLEX_PACKAGING_TEST_ROOT/attached"
                if [[ " $* " == *" -readonly "* ]]; then
                    touch "$PLEX_PACKAGING_TEST_ROOT/attached-readonly"
                fi
                if [[ "${PLEX_PACKAGING_TEST_FAIL_ATTACH:-}" == 1 ]]; then
                    exit 1
                fi
                printf '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>system-entities</key><array><dict><key>dev-entry</key><string>/dev/disk947</string></dict><dict><key>dev-entry</key><string>/dev/disk947s1</string><key>mount-point</key><string>%s</string></dict></array></dict></plist>\n' "$mount_dir"
                ;;
            detach)
                mount_dir="$(cat "$PLEX_PACKAGING_TEST_ROOT/attached")"
                [[ "$2" == "/dev/disk947s1" || "$2" == "$mount_dir" ]] || exit 1
                rm "$mount_dir/Applications" "$PLEX_PACKAGING_TEST_ROOT/attached"
                rm -f "$PLEX_PACKAGING_TEST_ROOT/attached-readonly"
                ;;
            convert) touch "${@: -1}" ;;
            verify) ;;
            *) exit 1 ;;
        esac
        ;;
    ditto)
        if [[ "${@: -2:1}" == *.app ]]; then
            [[ "${PLEX_PACKAGING_TEST_REJECT_APP_DITTO:-}" != 1 ]] || exit 1
            mkdir -p "${@: -1}"
        else
            touch "${@: -1}"
        fi
        ;;
    convert) touch "${@: -1}" ;;
    osascript)
        [[ "${PLEX_PACKAGING_TEST_FAIL_FINDER:-}" != 1 ]] || exit 1
        touch "$PLEX_PACKAGING_TEST_ROOT/added-finder-metadata"
        ;;
    xattr)
        [[ "$1" == -cr && "$2" == "$PLEX_PACKAGING_TEST_ROOT/"*"/mount/NowPlaying for Plex.app" ]] || exit 1
        rm -f "$PLEX_PACKAGING_TEST_ROOT/added-finder-metadata"
        ;;
    defaults|killall|SetFile|chflags|sleep|sync|sips|DeRez|Rez) ;;
    lipo)
        [[ $# == 2 && "$1" == -archs && -f "$2" ]] || exit 1
        printf '%s\n' "${PLEX_PACKAGING_TEST_ARCHS:-x86_64 arm64}"
        ;;
    codesign)
        [[ "${PLEX_PACKAGING_TEST_SIGNED_APP:-}" == 1 ]] || exit 1
        if [[ "${@: -1}" == "$PLEX_PACKAGING_TEST_ROOT/"*"/mount/NowPlaying for Plex.app" ]]; then
            [[ "$1" == --verify && " $* " == *" --strict "* && " $* " == *" --deep "* ]] || exit 1
            [[ -f "$PLEX_PACKAGING_TEST_ROOT/attached-readonly" && ! -f "$PLEX_PACKAGING_TEST_ROOT/added-finder-metadata" ]] || exit 1
            [[ "${PLEX_PACKAGING_TEST_FAIL_MOUNTED_SIGNATURE:-}" != 1 ]] || exit 1
            touch "$PLEX_PACKAGING_TEST_ROOT/verified-packaged-app"
        elif [[ "$1" == --sign ]]; then
            [[ -f "$PLEX_PACKAGING_TEST_ROOT/verified-packaged-app" && ! -f "$PLEX_PACKAGING_TEST_ROOT/attached" ]] || exit 1
            rm "$PLEX_PACKAGING_TEST_ROOT/verified-packaged-app"
        fi
        ;;
    xcrun)
        case "$1:$2" in
            notarytool:submit)
                if [[ "${PLEX_PACKAGING_TEST_FAIL_NOTARIZATION:-}" == 1 ]]; then
                    printf '%s\n' '{"status":"Invalid","id":"test-submission"}'
                else
                    printf '%s\n' '{"status":"Accepted","id":"test-submission"}'
                fi
                ;;
            stapler:staple) printf '%s\n' "signed and stapled release" > "$3" ;;
            stapler:validate) [[ "$(cat "$3")" == "signed and stapled release" ]] ;;
            *) exit 1 ;;
        esac
        ;;
    spctl) [[ "$(cat "${@: -1}")" == "signed and stapled release" ]] ;;
    *) exit 1 ;;
esac
