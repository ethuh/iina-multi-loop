#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$(mktemp -d /private/tmp/iina-multiloop-harness.XXXXXX)"
trap 'rm -rf "$BUILD_DIR"' EXIT

xcrun --sdk macosx swiftc \
  "$ROOT_DIR/iina/MultiLoopStore.swift" \
  "$ROOT_DIR/Tests/MultiLoopStoreHarness/Support.swift" \
  "$ROOT_DIR/Tests/MultiLoopStoreHarness/main.swift" \
  -module-cache-path "$BUILD_DIR/module-cache" \
  -lsqlite3 \
  -o "$BUILD_DIR/multiloop-store-harness"

"$BUILD_DIR/multiloop-store-harness"
