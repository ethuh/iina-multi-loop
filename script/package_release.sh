#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-multiloop([.][0-9]+)?$ ]]; then
  echo "usage: $0 v<major>.<minor>.<patch>-multiloop[.<revision>]" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/.build/codex-derived-data/Build/Products/Release/IINA.app"
ARTIFACT_DIR="$ROOT_DIR/.build/release-artifacts"
ARCHIVE="$ARTIFACT_DIR/IINA-$VERSION-macOS.zip"

"$ROOT_DIR/script/build_and_run.sh" build Release
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
mkdir -p "$ARTIFACT_DIR"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ARCHIVE"
shasum -a 256 "$ARCHIVE"
