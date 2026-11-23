#!/bin/bash
set -eu

tool="${0##*/}"
printf '%s %s\n' "$tool" "$*" >> "$PLEX_PACKAGING_TEST_LOG"

case "$tool" in
    hdiutil)
        case "$1" in
            create) touch "${@: -1}" ;;
            makehybrid)
                contents="${@: -1}"
                [[ -s "$contents/.background/background.png" && -s "$contents/.DS_Store" &&
                    -s "$contents/.VolumeIcon.icns" && -d "$contents/NowPlaying for Plex.app" ]] || exit 1
                [[ "$(readlink "$contents/Applications")" == /Applications ]] || exit 1
                touch "${@: -2:1}"
                ;;
            attach)
                mount_dir="${@: -1}"
                [[ "$mount_dir" == "$PLEX_PACKAGING_TEST_ROOT/"*"/mount" ]] || exit 1
                ln -s /Applications "$mount_dir/Applications"
                printf '%s\n' "$mount_dir" > "$PLEX_PACKAGING_TEST_ROOT/attached"
                if [[ "${PLEX_PACKAGING_TEST_FAIL_ATTACH:-}" == 1 ]]; then
                    exit 1
                fi
                printf '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>system-entities</key><array><dict><key>dev-entry</key><string>/dev/disk947</string></dict><dict><key>dev-entry</key><string>/dev/disk947s1</string><key>mount-point</key><string>%s</string></dict></array></dict></plist>\n' "$mount_dir"
                ;;
            detach)
                mount_dir="$(cat "$PLEX_PACKAGING_TEST_ROOT/attached")"
                [[ "$2" == "/dev/disk947s1" || "$2" == "$mount_dir" ]] || exit 1
                rm "$mount_dir/Applications" "$PLEX_PACKAGING_TEST_ROOT/attached"
                ;;
            convert) touch "${@: -1}" ;;
            verify) ;;
            *) exit 1 ;;
        esac
        ;;
    ditto)
        if [[ "$1" == *.app ]]; then
            mkdir -p "$2"
        else
            touch "$2"
        fi
        ;;
    convert) touch "${@: -1}" ;;
    osascript) [[ "${PLEX_PACKAGING_TEST_FAIL_FINDER:-}" != 1 ]] ;;
    defaults|killall|SetFile|chflags|sleep|sync|sips|DeRez|Rez) ;;
    lipo)
        [[ $# == 2 && "$1" == -archs && -f "$2" ]] || exit 1
        printf '%s\n' "${PLEX_PACKAGING_TEST_ARCHS:-x86_64 arm64}"
        ;;
    codesign) [[ "${PLEX_PACKAGING_TEST_SIGNED_APP:-}" == 1 ]] ;;
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
