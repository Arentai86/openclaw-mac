#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SERVER="$ROOT_DIR/OpenClaw/Resources/runtime/server/index.js"
TOKEN_FILE="$(mktemp)"
LOG_FILE="$(mktemp)"
PORT="${PORT:-$(ruby -rsocket -e 's = TCPServer.new("127.0.0.1", 0); puts s.addr[1]; s.close')}"
TOKEN="$(openssl rand -hex 32)"
printf "%s\n" "$TOKEN" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"

node --check "$SERVER" >/dev/null
node "$SERVER" --host=127.0.0.1 --port="$PORT" --data-dir="$(dirname "$TOKEN_FILE")" --auth-token-file="$TOKEN_FILE" >"$LOG_FILE" 2>&1 &
PID=$!
cleanup() {
  kill "$PID" >/dev/null 2>&1 || true
  rm -f "$TOKEN_FILE" "$LOG_FILE"
}
trap cleanup EXIT

for _ in {1..50}; do
  if grep -q "LISTENING_ON:$PORT" "$LOG_FILE"; then
    break
  fi
  sleep 0.1
done

if ! grep -q "LISTENING_ON:$PORT" "$LOG_FILE"; then
  echo "Server did not start" >&2
  cat "$LOG_FILE" >&2
  exit 1
fi

UNAUTH_CODE="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/health")"
AUTH_CODE="$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "http://127.0.0.1:$PORT/health")"
HTML_CODE="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/?token=$TOKEN")"

[[ "$UNAUTH_CODE" == "401" ]] || { echo "Expected unauth health 401, got $UNAUTH_CODE" >&2; exit 1; }
[[ "$AUTH_CODE" == "200" ]] || { echo "Expected auth health 200, got $AUTH_CODE" >&2; exit 1; }
[[ "$HTML_CODE" == "302" ]] || { echo "Expected token browser handoff 302, got $HTML_CODE" >&2; exit 1; }

echo "OpenClaw runtime smoke test passed on 127.0.0.1:$PORT"
