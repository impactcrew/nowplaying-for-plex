on run arguments
    set volumeRoot to (POSIX file (item 1 of arguments)) as alias
    set appFileName to item 2 of arguments
    tell application "Finder"
        set installerFolder to item volumeRoot
        open installerFolder
        set installerWindow to container window of installerFolder
        try
            set bounds of installerWindow to {100, 100, 700, 580}
            set current view of installerWindow to icon view
            set toolbar visible of installerWindow to false
            set statusbar visible of installerWindow to false

            set viewOptions to icon view options of installerWindow
            set arrangement of viewOptions to not arranged
            set icon size of viewOptions to 128
            set text size of viewOptions to 14
            set shows item info of viewOptions to false
            set shows icon preview of viewOptions to true
            set label position of viewOptions to bottom

            set backgroundFile to file "background.png" of folder ".background" of installerFolder
            set background picture of viewOptions to backgroundFile
            set position of item appFileName of installerFolder to {150, 200}
            set position of item "Applications" of installerFolder to {450, 200}
            update installerFolder without registering applications
            delay 1
        on error errorMessage number errorNumber
            close installerWindow
            error errorMessage number errorNumber
        end try
        close installerWindow
    end tell
end run
