# CRITICAL BUG ANALYSIS: NSURLErrorNotConnectedToInternet (Error -1009)

## ROOT CAUSE IDENTIFIED

The PlexWidget app is **NOT CODE SIGNED**, which causes macOS to restrict network access at the kernel level, even though:
- Entitlements are properly configured
- Sandbox is disabled
- Network client permissions are granted

When an unsigned app tries to use URLSession with hardened runtime enabled, macOS kernel blocks the network call with error `-1009: NSURLErrorNotConnectedToInternet`, regardless of actual network connectivity.

---

## EVIDENCE

### 1. Code Signing Status
```
codesign -d -v /Volumes/LIME2/Work/Development/plex-desktop-widget/PlexWidget/build/PlexWidget.app
Output: "code object is not signed at all"
```

### 2. Build Configuration Issue
File: `/Volumes/LIME2/Work/Development/plex-desktop-widget/PlexWidget/build.sh`
- Lines 34-36: **Disables code signing explicitly**
  ```bash
  CODE_SIGN_IDENTITY=""
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGNING_ALLOWED=NO
  ```
- Lines 48-50: **Repeats disable for second arch**

### 3. Project Configuration
File: `/Volumes/LIME2/Work/Development/plex-desktop-widget/PlexWidget/PlexWidget.xcodeproj/project.pbxproj`
- `ENABLE_HARDENED_RUNTIME = YES;` (both Debug and Release configs)
- `DEVELOPMENT_TEAM = "";` (EMPTY - no team assigned!)
- `CODE_SIGN_ENTITLEMENTS = PlexWidget/PlexWidget.entitlements;` (properly referenced)

### 4. Network Connectivity Verification
```bash
curl -v http://192.168.1.2:32400/status/sessions
→ HTTP/1.1 401 Unauthorized (proves server is reachable)
```

### 5. App Configuration
- Entitlements file: **CORRECT** - has `com.apple.security.network.client = true`
- Info.plist: **CORRECT** - minimal config with LSUIElement
- URLSession configuration: **CORRECT** - proper timeout and headers
- Network request code: **CORRECT** - follows best practices

---

## WHY THIS HAPPENS

On macOS with **hardened runtime enabled** (required for many system integrations):

1. **Unsigned binaries** are treated as low-trust by the kernel
2. **Entitlements don't apply** to unsigned code - they're verified during code signing
3. **URLSession.shared.data()** makes actual network calls to the kernel
4. **Kernel rejects** the call with `-1009` even though the server is reachable
5. **Error message is misleading** - it says "no internet" but really means "you're not authorized"

This is why curl works (different API stack) but URLSession fails (goes through kernel restrictions).

---

## THE FIX

### Option A: Code Sign Locally (RECOMMENDED FOR DEVELOPMENT)

Update `build.sh` to code sign with default identity:

```bash
# OLD - LINES 34-36
CODE_SIGN_IDENTITY=""
CODE_SIGNING_REQUIRED=NO
CODE_SIGNING_ALLOWED=NO

# NEW
CODE_SIGN_IDENTITY="-"
CODE_SIGNING_REQUIRED=YES
CODE_SIGNING_ALLOWED=YES
```

And update project config:
```
DEVELOPMENT_TEAM: Set to your Apple Team ID (get from Keychain Access)
```

### Option B: Remove Hardened Runtime (NOT RECOMMENDED - breaks features)

Set `ENABLE_HARDENED_RUNTIME = NO;` in both Debug and Release configurations.
This will break:
- App sandboxing
- Code signing verification
- System integration features

### Option C: Ad-hoc Sign After Build

Add to `build.sh` before returning:

```bash
# Ad-hoc sign the final app
echo "Signing app..."
codesign -s - "$UNIVERSAL_APP"
```

---

## RECOMMENDED FIX: Option A + Option C (Hybrid)

1. **Set DEVELOPMENT_TEAM** in Xcode project
2. **Update build.sh** to use proper code signing
3. **Sign with ad-hoc identity** as fallback

This allows:
- Local development and testing
- Network access works immediately
- Hardened runtime still active
- Easy transition to production signing later

---

## IMPLEMENTATION

### Step 1: Get Apple Team ID

```bash
# Show all code signing identities
security find-identity -v -p codesigning

# Or use ad-hoc signing (no team needed)
codesign -s - /path/to/app
```

### Step 2: Update build.sh

Replace lines 34-36 and 48-50:

```bash
# Build for Intel (x86_64)
echo ""
echo "Building for Intel (x86_64)..."
xcodebuild \
    -project "$PROJECT_DIR/$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -arch x86_64 \
    -derivedDataPath "$BUILD_DIR/DerivedData-x86_64" \
    ONLY_ACTIVE_ARCH=NO

# Build for Apple Silicon (arm64)
echo ""
echo "Building for Apple Silicon (arm64)..."
xcodebuild \
    -project "$PROJECT_DIR/$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -arch arm64 \
    -derivedDataPath "$BUILD_DIR/DerivedData-arm64" \
    ONLY_ACTIVE_ARCH=NO

# ... rest of script ...

# ADD AT END - AFTER UNIVERSAL BINARY CREATION
echo ""
echo "Code signing universal binary..."
codesign -s - --deep --force "$UNIVERSAL_APP"

echo ""
echo "Verifying code signature..."
codesign -v "$UNIVERSAL_APP"
```

### Step 3: Verify Fix

```bash
./build.sh
codesign -d -v ./build/PlexWidget.app
# Should show: valid on disk AND satisfied its Designated Requirement
```

---

## TESTING AFTER FIX

1. Run the built app from `/Applications/PlexWidget.app`
2. Go through onboarding
3. Network request should succeed (200 status code expected after auth)
4. Error should change from `-1009 No internet connection` to actual auth error if token is wrong

---

## PREVENTION

For future releases:

1. Always code sign (even with ad-hoc `-`) when using hardened runtime
2. If code signing fails, hardened runtime denies all privileged operations
3. Test network requests on actual built app, not just in Simulator
4. Verify signatures with: `codesign -v /path/to/app`

---

## BLOCKERS FOR v1.0 RELEASE

- [ ] Code signing applied to build.sh
- [ ] App runs from /Applications/ without security warnings
- [ ] Onboarding network validation works
- [ ] All three auth scenarios tested:
  - [ ] Valid server + valid token → Success
  - [ ] Invalid server → Appropriate error message
  - [ ] Invalid token → 401 auth error

