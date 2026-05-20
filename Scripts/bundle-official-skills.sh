#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$ROOT_DIR/OpenClaw/Resources/skills"
OPENCLAW_VERSION="${OPENCLAW_VERSION:-latest}"

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

NPM="$ROOT_DIR/OpenClaw/Resources/runtime/node-$HOST_NODE_ARCH/bin/npm"
if [ ! -x "$NPM" ]; then
  NPM="$(command -v npm)"
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "Downloading official OpenClaw skills from openclaw@$OPENCLAW_VERSION"
"$NPM" pack "openclaw@$OPENCLAW_VERSION" --pack-destination "$TMP_DIR" --silent >/dev/null
mkdir -p "$TMP_DIR/package"
tar -xzf "$TMP_DIR"/*.tgz -C "$TMP_DIR/package" --strip-components=1

if [ ! -d "$TMP_DIR/package/skills" ]; then
  echo "OpenClaw package did not contain a skills directory" >&2
  exit 1
fi

rm -rf "$SKILLS_DIR"
mkdir -p "$(dirname "$SKILLS_DIR")"
cp -R "$TMP_DIR/package/skills" "$SKILLS_DIR"

COUNT="$(find "$SKILLS_DIR" -maxdepth 2 -type f -name SKILL.md | wc -l | tr -d ' ')"
if [ "$COUNT" = "0" ]; then
  echo "No official skills were bundled" >&2
  exit 1
fi

cat > "$SKILLS_DIR/version.json" <<JSON
{
  "source": "openclaw@$OPENCLAW_VERSION",
  "count": $COUNT
}
JSON

echo "Bundled $COUNT official skills in $SKILLS_DIR"
