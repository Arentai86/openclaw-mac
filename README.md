# OpenClaw for macOS

OpenClaw for macOS is a native SwiftUI menu bar launcher for the OpenClaw local server. It bundles the runtime, starts and monitors the server, opens the browser UI, stores provider credentials in Keychain, and prepares the distribution path for Developer ID signing, notarization, DMG releases, and Sparkle updates.

## Status

This repository is a working launcher scaffold with a secured fallback runtime. It includes:

- SwiftUI `MenuBarExtra` app with `LSUIElement=true`.
- First-run wizard for system checks, data location, port selection, API keys, and launch preferences.
- `Process`-based server manager with stdout/stderr logging, health checks, retry backoff, and termination cleanup.
- Runtime resolver for bundled Node or a custom Node path.
- Local auth token generation with `0600` permissions.
- Keychain storage with explicit accessibility and macOS data protection keychain support.
- Preferences, uninstaller with path allowlist, diagnostics export, and Sparkle update hook.
- Build, bundle, sign, notarize, DMG, appcast, GitHub Actions release scripts, and runtime smoke test.

## Requirements

- macOS 13 Ventura or newer.
- Xcode 15 or newer selected with `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
- Node.js on the development machine for fallback-runtime smoke tests.
- Apple Developer Program membership for public distribution.
- Developer ID Application certificate and app-specific password for notarization.

## Local Development

```bash
git clone https://github.com/openclaw/openclaw-mac.git
cd openclaw-mac
SKIP_NODE_DOWNLOAD=1 SKIP_SERVER_DOWNLOAD=1 ./Scripts/bundle-runtime.sh
bash Scripts/smoke-test-runtime.sh
./Scripts/build.sh
```

For a real runtime bundle:

```bash
OPENCLAW_REPO=https://github.com/YOUR_ORG/openclaw.git \
OPENCLAW_VERSION=v0.1.0 \
./Scripts/bundle-runtime.sh
./Scripts/build.sh
```

## Distribution

Release builds are designed around Developer ID distribution outside the Mac App Store:

```bash
./Scripts/bundle-runtime.sh
./Scripts/build.sh
IDENTITY="Developer ID Application: Your Name (TEAMID)" ./Scripts/sign.sh
APPLE_ID=... TEAM_ID=... APP_SPECIFIC_PASSWORD=*** ./Scripts/notarize.sh
IDENTITY="Developer ID Application: Your Name (TEAMID)" NOTARIZE_DMG=1 ./Scripts/make-dmg.sh
SPARKLE_PRIVATE_KEY=... ./Scripts/appcast.sh
```

## Security Model

The server binds only to `127.0.0.1`. The launcher creates a random 32-byte auth token at:

```text
~/Library/Application Support/OpenClaw/auth_token
```

The file is written with `0600` permissions. The fallback runtime requires the token for `/health` and browser access, then redirects away from the query-token URL into an HTTP-only same-site cookie.

## License

MIT. See [LICENSE](LICENSE).
