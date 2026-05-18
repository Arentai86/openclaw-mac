#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME_DIR="$ROOT_DIR/OpenClaw/Resources/runtime"
NODE_VERSION="${NODE_VERSION:-20.11.0}"
OPENCLAW_VERSION="${OPENCLAW_VERSION:-main}"
OPENCLAW_REPO="${OPENCLAW_REPO:-https://github.com/openclaw/openclaw.git}"

mkdir -p "$RUNTIME_DIR"

if [[ "${SKIP_NODE_DOWNLOAD:-0}" != "1" ]]; then
  for ARCH in arm64 x64; do
    ARCHIVE="node-v$NODE_VERSION-darwin-$ARCH.tar.gz"
    URL="https://nodejs.org/dist/v$NODE_VERSION/$ARCHIVE"
    echo "Downloading $URL"
    curl -fsSL "$URL" -o "$ROOT_DIR/$ARCHIVE"
    rm -rf "$RUNTIME_DIR/node-$ARCH"
    mkdir -p "$RUNTIME_DIR/node-$ARCH"
    tar -xzf "$ROOT_DIR/$ARCHIVE" -C "$RUNTIME_DIR/node-$ARCH" --strip-components=1
    rm "$ROOT_DIR/$ARCHIVE"
  done
fi

if [[ "${SKIP_SERVER_DOWNLOAD:-0}" != "1" ]]; then
  rm -rf "$RUNTIME_DIR/server"
  git clone --depth 1 --branch "$OPENCLAW_VERSION" "$OPENCLAW_REPO" "$RUNTIME_DIR/server"
fi

if [[ -f "$RUNTIME_DIR/server/package-lock.json" ]]; then
  HOST_ARCH="$(uname -m)"
  if [[ "$HOST_ARCH" == "arm64" ]]; then
    NPM="$RUNTIME_DIR/node-arm64/bin/npm"
  else
    NPM="$RUNTIME_DIR/node-x64/bin/npm"
  fi
  "$NPM" ci --omit=dev --prefix "$RUNTIME_DIR/server"
fi

cat > "$RUNTIME_DIR/version.json" <<JSON
{
  "version": "$OPENCLAW_VERSION",
  "node": "$NODE_VERSION"
}
JSON

echo "Runtime bundled in $RUNTIME_DIR"

