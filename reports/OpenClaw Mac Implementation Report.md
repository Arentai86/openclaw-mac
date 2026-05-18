# OpenClaw Mac Implementation Report

Date: 2026-05-18
Project: `/Users/artem/Projects/openclaw-mac`

## Result

OpenClaw Mac launcher has been stabilized as a local working macOS launcher scaffold. The source tree is clean, generated build artifacts were removed, security-critical localhost/runtime pieces were tightened, validation checks pass, and a local baseline git commit was created.

This is not yet a public notarized production release because Apple Developer Program credentials, Developer ID certificate, Sparkle production key, and full Xcode installation are external/manual prerequisites.

## Implemented / verified

- SwiftUI menu bar launcher structure is present.
- First-run wizard structure is present.
- Preferences, About, Advanced, Server and General tabs are present.
- Server manager starts a bundled runtime through `Process`.
- Health checks use bearer token auth.
- Runtime resolver supports architecture-specific bundled Node and custom Node path.
- Auth token is 32 random bytes encoded as 64 hex chars.
- Auth token file is created with `0600` permissions; data dir with `0700` where possible.
- Keychain fallback implementation now uses add-or-update instead of delete-then-add.
- Keychain fallback sets explicit `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- macOS Keychain fallback sets `kSecUseDataProtectionKeychain: true`.
- Uninstaller uses an allowlist before deleting user files.
- Fallback runtime is no longer just a placeholder page: it is a secured local runtime smoke target.
- Fallback runtime binds to `127.0.0.1`.
- Fallback runtime requires auth for `/health` and browser page access.
- Fallback runtime restricts CORS to localhost origins.
- Browser handoff with `?token=` redirects away from the query token and sets an HTTP-only same-site cookie.
- Release scripts fail explicitly when signing identity is missing instead of using fake placeholder identity.
- GitHub build workflow runs runtime smoke test before build.
- GitHub release workflow cleans up signing keychain and `cert.p12` after execution.
- README and SECURITY docs updated to match actual behavior.
- Generated `build/` folder was removed from the project.
- Scripts are executable.
- Local baseline commit created.

## Files changed materially

- `OpenClaw/Storage/KeychainStore.swift`
- `OpenClaw/Storage/AuthToken.swift`
- `OpenClaw/Uninstall/Uninstaller.swift`
- `OpenClaw/Resources/runtime/server/index.js`
- `Scripts/smoke-test-runtime.sh`
- `Scripts/sign.sh`
- `Scripts/make-dmg.sh`
- `.github/workflows/build.yml`
- `.github/workflows/release.yml`
- `README.md`
- `docs/SECURITY.md`

## Validation performed

Command-level validations completed successfully:

- `bash -n Scripts/*.sh`
- `node --check OpenClaw/Resources/runtime/server/index.js`
- `bash Scripts/smoke-test-runtime.sh`
- `swiftc -parse-as-library -target arm64-apple-macos13.0 ...`
- `plutil -lint OpenClaw/Resources/Info.plist OpenClaw/Resources/OpenClaw.entitlements OpenClaw.xcodeproj/project.pbxproj`
- `git status --short` after commit

Runtime smoke result:

- unauthorized `/health` returns `401`
- authorized `/health` returns `200`
- browser token handoff returns `302`
- server prints `LISTENING_ON:7842`

## Remaining manual blockers

These cannot be completed by code changes alone:

1. Install/select full Xcode.
   - Current `xcode-select -p`: `/Library/Developer/CommandLineTools`
   - `xcodebuild` currently fails because full Xcode is not selected/installed.
   - `/Applications/Xcode.app` was not found.

2. Apple Developer Program.
   - Needed for Developer ID Application certificate.
   - Needed for Gatekeeper-friendly distribution.

3. Notarization credentials.
   - `APPLE_ID`
   - `TEAM_ID`
   - `APP_SPECIFIC_PASSWORD`

4. Production Sparkle key.
   - `SUPublicEDKey` in `Info.plist` is still `REPLACE_WITH_SPARKLE_PUBLIC_EDDSA_KEY` until a real Sparkle EdDSA key pair is generated.
   - `SPARKLE_PRIVATE_KEY` must be stored only in CI secrets / secure local storage.

5. Real OpenClaw server runtime.
   - Current bundled server is a secured fallback runtime for launcher validation.
   - Production release must bundle the real `openclaw` server via `Scripts/bundle-runtime.sh` or switch to a single binary runtime.

## Recommended next commands after installing Xcode

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
cd /Users/artem/Projects/openclaw-mac
SKIP_NODE_DOWNLOAD=1 SKIP_SERVER_DOWNLOAD=1 ./Scripts/bundle-runtime.sh
./Scripts/smoke-test-runtime.sh
./Scripts/build.sh
```

For production runtime:

```bash
OPENCLAW_REPO=https://github.com/YOUR_ORG/openclaw.git \
OPENCLAW_VERSION=v0.1.0 \
./Scripts/bundle-runtime.sh
./Scripts/build.sh
```

For signing/release after credentials are ready:

```bash
IDENTITY="Developer ID Application: Your Name (TEAMID)" ./Scripts/sign.sh
APPLE_ID=... TEAM_ID=... APP_SPECIFIC_PASSWORD=... ./Scripts/notarize.sh
IDENTITY="Developer ID Application: Your Name (TEAMID)" NOTARIZE_DMG=1 ./Scripts/make-dmg.sh
SPARKLE_PRIVATE_KEY=... ./Scripts/appcast.sh
```
