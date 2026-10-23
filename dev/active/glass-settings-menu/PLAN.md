# Dark translucent settings menu

## Final scope

Restore the original dark menu character with a more transparent background and keep Change Server directly beneath the server address. The user rejected the pale native glass presentation and explicitly requested this correction.

## Implementation

Use a 60 percent charcoal shape fill with no native HUD material or blur, providing 40 percent direct desktop visibility. Force dark appearance for this menu and retain semantic foreground colors. Restore orange selection gradients and remove the added minimum-height Change Server frame. Retain accessibility improvements, the standard launch switch, settings bindings, and the widget border fix.

## Verification

Release arm64 build passed with Xcode 27.1. Code and security reviews reported no findings. The installed app signature passed verification and its executable SHA-256 matches the build. The app was backed up and restarted successfully. Desktop-control tools are unavailable, so final visual confirmation remains pending. No publication or push.

## Project preference

The menu stays dark and translucent independently of system appearance. Preserve the original close spacing between the server address and Change Server.

## Direct desktop transparency

The user could not see the desktop through the HUD blur and tint. System Reduce Transparency was checked and is disabled. Remove the native HUD material and its now-unused mask from the settings panel, retaining only the 60 percent charcoal fill inside the same shape. This gives 40 percent direct desktop visibility without additional material shading or blur. Preserve the opaque accessibility variant, dark appearance, gradients, and footer spacing.

The direct-transparency correction passed the Release build, code review, security review, installed signature verification, matching executable check, and relaunch. Visual acceptance remains pending.
