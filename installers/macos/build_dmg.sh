#!/usr/bin/env bash
# Builds DocFlip-<version>-macos-universal.dmg from the release build.
# Usage: installers/macos/build_dmg.sh <version>
set -euo pipefail
VERSION="${1:?usage: build_dmg.sh <version>}"
APP="build/macos/Build/Products/Release/DocFlip.app"
OUT="DocFlip-${VERSION}-macos-universal.dmg"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$OUT"
hdiutil create -volname "DocFlip" -srcfolder "$STAGE" -ov -format UDZO "$OUT"
echo "Created $OUT"
