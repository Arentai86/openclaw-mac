# Development

## Setup

Install Xcode 15 or newer and select it:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

Resolve Swift Package dependencies in Xcode or through `xcodebuild` during the first build. The project references:

- Sparkle
- KeychainAccess
- swift-log

## Build with placeholder runtime

```bash
SKIP_NODE_DOWNLOAD=1 SKIP_SERVER_DOWNLOAD=1 ./Scripts/bundle-runtime.sh
./Scripts/build.sh
```

The placeholder server is useful for UI iteration but does not replace the real OpenClaw runtime.

## Bundle real runtime

```bash
OPENCLAW_REPO=https://github.com/YOUR_ORG/openclaw.git \
OPENCLAW_VERSION=v0.1.0 \
./Scripts/bundle-runtime.sh
```

`bundle-runtime.sh` downloads Node for `arm64` and `x64`, clones the OpenClaw server, installs production npm dependencies, and writes `version.json`.

## Coding rules

- Keep launcher state in `AppState`.
- Keep process lifecycle in `ServerManager` and `ServerProcess`.
- Never bind the server to `0.0.0.0`.
- Any API key must go through `KeychainStore`.
- Any new file path should go through `Paths`.

## Useful commands

```bash
plutil -lint OpenClaw/Resources/Info.plist OpenClaw/Resources/OpenClaw.entitlements
bash -n Scripts/*.sh
```

