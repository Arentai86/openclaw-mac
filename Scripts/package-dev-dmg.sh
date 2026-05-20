#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP="$BUILD_DIR/test/OpenClaw.app"
STAGING="$BUILD_DIR/dmg-staging"
DMG_NAME="${DMG_NAME:-OpenClaw-dev-tested.dmg}"
DMG="$BUILD_DIR/$DMG_NAME"
NODE_VERSION="${NODE_VERSION:-22.19.0}"
VERSION="${VERSION:-0.1.16-test}"
BUILD_NUMBER="${BUILD_NUMBER:-17}"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
MODULE_CACHE="$BUILD_DIR/module-cache"
ARCH_BUILD_DIR="$BUILD_DIR/arch"

cd "$ROOT_DIR"

case "$(uname -m)" in
  arm64)
    HOST_NODE_ARCH="arm64"
    ;;
  x86_64)
    HOST_NODE_ARCH="x64"
    ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

echo "Keeping existing DMG files until the new image is verified"
mkdir -p "$BUILD_DIR"

echo "Validating project metadata"
plutil -lint \
  OpenClaw.xcodeproj/project.pbxproj \
  OpenClaw/Resources/Info.plist \
  OpenClaw/Resources/OpenClaw.entitlements >/dev/null
xmllint --noout OpenClaw.xcodeproj/xcshareddata/xcschemes/OpenClaw.xcscheme
bash -n Scripts/*.sh

echo "Testing bundled fallback runtime"
./Scripts/smoke-test-runtime.sh

if [ ! -d "OpenClaw/Resources/skills" ] || [ "$(find OpenClaw/Resources/skills -maxdepth 2 -type f -name SKILL.md | wc -l | tr -d ' ')" = "0" ]; then
  ./Scripts/bundle-official-skills.sh
fi

echo "Typechecking Swift 6 sources"
mkdir -p "$MODULE_CACHE"
env CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" xcrun --sdk macosx swiftc \
  -swift-version 6 \
  -typecheck \
  OpenClaw/App/*.swift \
  OpenClaw/Server/*.swift \
  OpenClaw/Runtime/*.swift \
  OpenClaw/Wizard/*.swift \
  OpenClaw/Wizard/Steps/*.swift \
  OpenClaw/MenuBar/*.swift \
  OpenClaw/Preferences/*.swift \
  OpenClaw/Updates/*.swift \
  OpenClaw/Storage/*.swift \
  OpenClaw/Uninstall/*.swift

echo "Creating app bundle"
rm -rf "$BUILD_DIR/test" "$STAGING" "$DMG"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp -R OpenClaw/Resources/runtime "$APP/Contents/Resources/runtime"
cp -R OpenClaw/Resources/skills "$APP/Contents/Resources/skills"
cp OpenClaw/Resources/OpenClaw.icns "$APP/Contents/Resources/OpenClaw.icns"
cp OpenClaw/Resources/OpenzenMark.png "$APP/Contents/Resources/OpenzenMark.png"
cp OpenClaw/Resources/Info.plist "$APP/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleDevelopmentRegion en" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable OpenClaw" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.openclaw.app" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile OpenClaw" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"

ensure_node() {
  local node_arch="$1"
  local node_dir="$APP/Contents/Resources/runtime/node-$node_arch"
  if [ -x "$node_dir/bin/node" ] && [ "$("$node_dir/bin/node" --version)" = "v$NODE_VERSION" ]; then
    return
  fi

  local archive="$BUILD_DIR/node-v$NODE_VERSION-darwin-$node_arch.tar.gz"
  echo "Downloading Node.js $NODE_VERSION for $node_arch"
  rm -rf "$node_dir"
  curl -fsSL "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-darwin-$node_arch.tar.gz" -o "$archive"
  mkdir -p "$node_dir"
  tar -xzf "$archive" -C "$node_dir" --strip-components=1
  rm "$archive"
}

ensure_node arm64
ensure_node x64

echo "Testing bundled npm PATH isolation"
NODE_DIR="$APP/Contents/Resources/runtime/node-$HOST_NODE_ARCH"
env -i HOME="$HOME" PATH="$NODE_DIR/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  "$NODE_DIR/bin/npm" --version >/dev/null

echo "Smoke-testing app-bundled runtime"
TEST_PORT="$(ruby -rsocket -e 's = TCPServer.new("127.0.0.1", 0); puts s.addr[1]; s.close')"
OPENCLAW_AUTH_TOKEN="dev-health-token" "$NODE_DIR/bin/node" \
  "$APP/Contents/Resources/runtime/server/index.js" \
  --host=127.0.0.1 \
  --port="$TEST_PORT" >"$BUILD_DIR/runtime-smoke.log" 2>&1 &
SERVER_PID=$!
cleanup_server() {
  kill "$SERVER_PID" >/dev/null 2>&1 || true
  wait "$SERVER_PID" >/dev/null 2>&1 || true
}
trap cleanup_server EXIT

for _ in {1..50}; do
  if curl -fsS -H "Authorization: Bearer dev-health-token" "http://127.0.0.1:$TEST_PORT/health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
curl -fsS -H "Authorization: Bearer dev-health-token" "http://127.0.0.1:$TEST_PORT/health" >/dev/null
curl -fsS "http://127.0.0.1:$TEST_PORT/?token=dev-health-token" >/dev/null
cleanup_server
trap - EXIT

echo "Compiling app executable"
rm -rf "$ARCH_BUILD_DIR"
mkdir -p "$ARCH_BUILD_DIR" "$MODULE_CACHE/arm64" "$MODULE_CACHE/x86_64"

compile_arch() {
  local arch="$1"
  local target="$2"
  local output="$ARCH_BUILD_DIR/OpenClaw-$arch"
  echo "Compiling $arch"
  find OpenClaw -name "*.swift" -print0 | xargs -0 xcrun --sdk macosx swiftc \
    -swift-version 6 \
    -target "$target" \
    -sdk "$SDK_PATH" \
    -module-cache-path "$MODULE_CACHE/$arch" \
    -parse-as-library \
    -O \
    -o "$output"
}

compile_arch arm64 arm64-apple-macosx13.0
compile_arch x86_64 x86_64-apple-macosx13.0
lipo -create "$ARCH_BUILD_DIR/OpenClaw-arm64" "$ARCH_BUILD_DIR/OpenClaw-x86_64" \
  -output "$APP/Contents/MacOS/OpenClaw"
chmod +x "$APP/Contents/MacOS/OpenClaw"
lipo -info "$APP/Contents/MacOS/OpenClaw"
file "$APP/Contents/Resources/runtime/node-arm64/bin/node"
file "$APP/Contents/Resources/runtime/node-x64/bin/node"

echo "Signing app ad-hoc"
codesign --force --deep --sign - --entitlements OpenClaw/Resources/OpenClaw.entitlements "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "Creating DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/OpenClaw.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "OpenClaw Test" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
hdiutil verify "$DMG"

echo "Mount-testing DMG"
MOUNT_INFO="$(hdiutil attach "$DMG" -nobrowse -readonly)"
MOUNT_POINT="$(printf '%s\n' "$MOUNT_INFO" | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/")); exit}')"
test -d "$MOUNT_POINT/OpenClaw.app"
test -L "$MOUNT_POINT/Applications"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$MOUNT_POINT/OpenClaw.app/Contents/Info.plist")" = "$VERSION"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$MOUNT_POINT/OpenClaw.app/Contents/Info.plist")" = "OpenClaw"
test -f "$MOUNT_POINT/OpenClaw.app/Contents/Resources/OpenClaw.icns"
test -f "$MOUNT_POINT/OpenClaw.app/Contents/Resources/OpenzenMark.png"
test "$(find "$MOUNT_POINT/OpenClaw.app/Contents/Resources/skills" -maxdepth 2 -type f -name SKILL.md | wc -l | tr -d ' ')" -gt 0
hdiutil detach "$MOUNT_POINT"

echo "Cleaning packaging intermediates"
rm -rf "$BUILD_DIR/test" "$STAGING" "$BUILD_DIR/runtime-smoke.log" "$MODULE_CACHE" "$ARCH_BUILD_DIR"

echo "Created $DMG"
ls -lh "$DMG"
