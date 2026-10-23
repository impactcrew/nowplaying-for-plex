# Dark translucent settings menu

## Final scope

Restore the original dark menu character with a more transparent background and keep Change Server directly beneath the server address. The user rejected the pale native glass presentation and explicitly requested this correction.

## Implementation

Use the masked native HUD blur with a 60 percent charcoal overlay instead of the original 85 percent. Force dark appearance for this menu and retain semantic foreground colors. Restore orange selection gradients and remove the added minimum-height Change Server frame. Retain accessibility improvements, the standard launch switch, settings bindings, and the widget border fix.

## Verification

Release arm64 build passed with Xcode 27.1. Code and security reviews reported no findings. The installed app signature passed verification and its executable SHA-256 matches the build. The app was backed up and restarted successfully. Desktop-control tools are unavailable, so final visual confirmation remains pending. No publication or push.

## Project preference

The menu stays dark and translucent independently of system appearance. Preserve the original close spacing between the server address and Change Server.
