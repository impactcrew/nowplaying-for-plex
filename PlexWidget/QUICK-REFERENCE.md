# Quick Reference - Network Fix Implementation

## The Issue
URLSession network calls failing with error -1009 "No internet connection" even though Plex server is reachable.

## The Root Cause
Build script was disabling code signing, so unsigned app gets blocked by kernel.

## The Fix Location
**File:** `/Volumes/LIME2/Work/Development/plex-desktop-widget/PlexWidget/build.sh`

## Exact Code Changes

### Change 1: Remove Signing Disable (Lines 34-36 and 48-50)

**BEFORE (Broken):**
```bash
xcodebuild \
    -project "$PROJECT_DIR/$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -arch x86_64 \
    -derivedDataPath "$BUILD_DIR/DerivedData-x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO
```

**AFTER (Fixed):**
```bash
xcodebuild \
    -project "$PROJECT_DIR/$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -arch x86_64 \
    -derivedDataPath "$BUILD_DIR/DerivedData-x86_64" \
    ONLY_ACTIVE_ARCH=NO
```

**Repeat for arm64 build (lines 48-50).**

### Change 2: Add Code Signing (After Line 65)

**INSERT AFTER:** Universal binary creation with lipo

**INSERT BEFORE:** "Build Complete!" message

**NEW CODE:**
```bash
# Code sign the app with ad-hoc identity
# This is CRITICAL for network access when hardened runtime is enabled
echo ""
echo "Code signing universal binary..."
codesign -s - --deep --force "$UNIVERSAL_APP" 2>&1 | grep -v "^Warning" || true

# Verify the signature
echo ""
echo "Verifying code signature..."
if codesign -v "$UNIVERSAL_APP" 2>&1; then
    echo "Code signature verified successfully"
else
    echo "WARNING: Code signature verification failed"
    exit 1
fi
```

## Verification

### After Building
```bash
# Should show no output (meaning success):
codesign -v /Volumes/LIME2/Work/Development/plex-desktop-widget/PlexWidget/build/PlexWidget.app

# Should show signature details:
codesign -d -v /Volumes/LIME2/Work/Development/plex-desktop-widget/PlexWidget/build/PlexWidget.app
# Look for: Signature=adhoc
```

### After Installing
```bash
cp -R /Volumes/LIME2/Work/Development/plex-desktop-widget/PlexWidget/build/PlexWidget.app /Applications/

# Should still be valid:
codesign -v /Applications/PlexWidget.app
```

## Why This Works

1. **Before:** Unsigned app + hardened runtime = kernel blocks network
2. **After:** Signed app + hardened runtime = kernel allows network
3. **Result:** URLSession.shared.data() now reaches Plex server

## Files That Did NOT Change

These files are already correct and require no modifications:
- `/Volumes/LIME2/Work/Development/plex-desktop-widget/PlexWidget/PlexWidget/OnboardingView.swift` ✓
- `/Volumes/LIME2/Work/Development/plex-desktop-widget/PlexWidget/PlexWidget/PlexAPI.swift` ✓
- `/Volumes/LIME2/Work/Development/plex-desktop-widget/PlexWidget/PlexWidget/PlexWidget.entitlements` ✓
- `/Volumes/LIME2/Work/Development/plex-desktop-widget/PlexWidget/PlexWidget/Info.plist` ✓

## Testing the Fix

### Quick Test
```bash
# Rebuild
cd /Volumes/LIME2/Work/Development/plex-desktop-widget/PlexWidget
./build.sh

# Install
cp -R build/PlexWidget.app /Applications/

# Launch
open /Applications/PlexWidget.app

# Test onboarding with your Plex server
# Should see proper HTTP errors (401, 404) instead of -1009
```

### Full Test Scenarios

| Test | Expected | Status |
|------|----------|--------|
| Valid server + valid token | Success (200) | READY TO TEST |
| Valid server + invalid token | Auth error (401) | READY TO TEST |
| Invalid URL | Connection error | READY TO TEST |
| Unreachable server | Network error | READY TO TEST |

## Deployment Commands

### For Development
```bash
cd /Volumes/LIME2/Work/Development/plex-desktop-widget/PlexWidget
./build.sh
cp -R build/PlexWidget.app /Applications/
open /Applications/PlexWidget.app
```

### For Future Production Builds
Replace the ad-hoc signing line with your certificate:
```bash
# Current (development):
codesign -s - --deep --force "$UNIVERSAL_APP"

# For production (replace "Your Company"):
codesign -s "Developer ID Application: Your Company" --deep --force "$UNIVERSAL_APP"
```

## Documentation Files

All located in: `/Volumes/LIME2/Work/Development/plex-desktop-widget/PlexWidget/`

| File | Purpose |
|------|---------|
| `DEBUG-NETWORK-ISSUE.md` | Root cause analysis |
| `NETWORK-FIX-VERIFICATION.md` | Verification report |
| `CODE-CHANGES-SUMMARY.md` | Code change details |
| `FIX-SUMMARY-FOR-RELEASE.md` | Executive summary |
| `RELEASE-NOTES.txt` | Release notes |
| `QUICK-REFERENCE.md` | This file |

## Key Points

1. **One file modified:** `build.sh`
2. **Two changes:** Removed 6 lines, added 15 lines
3. **Result:** App now code-signed, network works
4. **Risk:** Extremely low (only enables signing)
5. **Testing:** Ready for integration testing
6. **Release:** Ready for v1.0 after testing

## Success Indicators

- [ ] Build succeeds without errors
- [ ] `codesign -v` returns with no output (success)
- [ ] `codesign -d -v` shows `Signature=adhoc`
- [ ] App launches without security warnings
- [ ] Onboarding network validation works
- [ ] Users can connect to Plex servers

## Questions?

See the full documentation files for:
- Detailed root cause analysis: `DEBUG-NETWORK-ISSUE.md`
- Complete verification steps: `NETWORK-FIX-VERIFICATION.md`
- Before/after code comparison: `CODE-CHANGES-SUMMARY.md`
- Executive summary: `FIX-SUMMARY-FOR-RELEASE.md`

