#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Whirl"
BUNDLE_ID="com.baiyanwu.whirl"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/RunDerivedData"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

stop_existing_app() {
  local pid parent_pid parent_command
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    parent_pid="$(ps -o ppid= -p "$pid" | tr -d ' ')"
    parent_command="$(ps -o command= -p "$parent_pid" 2>/dev/null || true)"
    if [[ "$parent_command" == *debugserver* ]]; then
      kill "$parent_pid" 2>/dev/null || true
    else
      kill "$pid" 2>/dev/null || true
    fi
  done < <(pgrep -f "^${APP_BINARY}$" || true)

  for _ in {1..20}; do
    pgrep -f "^${APP_BINARY}$" >/dev/null || return 0
    sleep 0.1
  done

  while IFS= read -r pid; do
    [[ -n "$pid" ]] && kill -9 "$pid" 2>/dev/null || true
  done < <(pgrep -f "^${APP_BINARY}$" || true)
}

build_app() {
  xcodebuild \
    -project "$ROOT_DIR/Whirl.xcodeproj" \
    -scheme Whirl \
    -configuration Debug \
    -derivedDataPath "$DERIVED_DATA" \
    build
}

open_app() {
  /usr/bin/open "$APP_BUNDLE"
}

stop_existing_app
build_app

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    /usr/bin/lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -f "^${APP_BINARY}$" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
