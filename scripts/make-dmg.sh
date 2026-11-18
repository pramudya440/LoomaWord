#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="ReaDeepL"
APP="dist/${APP_NAME}.app"
DMG="dist/${APP_NAME}.dmg"
STAGE="dist/.dmg-stage"

# Build the app first
zsh scripts/make-app.sh

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

diskutil image create from "$STAGE" --volumeName "$APP_NAME" --format UDZO "$DMG"
rm -rf "$STAGE"
echo "dmg built: $DMG"
