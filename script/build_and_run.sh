#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="IINA"
BUNDLE_ID="com.colliderli.iina"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.build/codex-derived-data"
SOURCE_PACKAGES_DIR="$ROOT_DIR/.build/codex-source-packages"
CONFIGURATION="${IINA_BUILD_CONFIGURATION:-${2:-Debug}}"
DEPLOYMENT_TARGET="${IINA_DEPLOYMENT_TARGET:-12.0}"
APP_BUNDLE="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"

build_app() {
  xcodebuild \
    -project "$ROOT_DIR/iina.xcodeproj" \
    -scheme iina \
    -configuration "$CONFIGURATION" \
    MACOSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR" \
    build
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

if [[ "$MODE" != "build" && "$MODE" != "--build" ]]; then
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
fi

build_app

case "$MODE" in
  build|--build)
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
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
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [build|run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
