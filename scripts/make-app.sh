#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="LoomaWord"
APP="dist/${APP_NAME}.app"
DEV=".dev"
STUB="$DEV/Launcher"

# --- Versioning -------------------------------------------------------------
# Override with: VERSION=1.2.0 BUILD=42 ./scripts/make-app.sh
# Defaults come from the latest git tag (falls back to 1.1.0) and commit count.
GIT_TAG_VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)
VERSION="${VERSION:-${GIT_TAG_VERSION:-1.1.0}}"
BUILD_NUMBER="${BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
echo "📦 Version ${VERSION} (build ${BUILD_NUMBER})"

# --- Signing ----------------------------------------------------------------
# Ad-hoc by default (works locally, but Gatekeeper will warn on other Macs).
# For a distributable release set SIGN_ID, e.g.:
#   SIGN_ID="Developer ID Application: Your Name (TEAMID)" ./scripts/make-app.sh
SIGN_ARGS=(--force --sign -)
if [[ -n "${SIGN_ID:-}" ]]; then
  echo "🔏 Signing with: $SIGN_ID"
  SIGN_ARGS=(--force --sign "$SIGN_ID" --options runtime --timestamp)
fi

# --- 1. Build the dynamic library (universal) -------------------------------
SCRATCH="$HOME/Library/Caches/LoomaWordBuild"
echo "🔨 Building LoomaWordLib (arm64 + x86_64)..."
swift build -c release --product LoomaWordLib \
  --arch arm64 --arch x86_64 \
  --scratch-path "$SCRATCH"
LIB="$SCRATCH/release/libLoomaWordLib.dylib"

# --- 2. Build launcher stub (universal, rebuilt when source changes) --------
mkdir -p "$DEV"
if [ ! -f "$STUB" ] || [ Tools/Launcher/main.swift -nt "$STUB" ] \
   || ! lipo -info "$STUB" 2>/dev/null | grep -q x86_64; then
  echo "🔨 Compiling launcher stub..."
  swiftc -O -target arm64-apple-macos14.0  Tools/Launcher/main.swift -o "$DEV/Launcher-arm64"
  swiftc -O -target x86_64-apple-macos14.0 Tools/Launcher/main.swift -o "$DEV/Launcher-x86_64"
  lipo -create "$DEV/Launcher-arm64" "$DEV/Launcher-x86_64" -output "$STUB"
  rm -f "$DEV/Launcher-arm64" "$DEV/Launcher-x86_64"
  codesign "${SIGN_ARGS[@]}" "$STUB"
fi

# --- 3. Assemble .app bundle ------------------------------------------------
echo "📦 Assembling ${APP_NAME}.app..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Resources"
cp "$STUB" "$APP/Contents/MacOS/$APP_NAME"
cp "$LIB" "$APP/Contents/Frameworks/libLoomaWordLib.dylib"

# --- 4. Generate Info.plist -------------------------------------------------
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>com.pramudya.loomaword</string>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>LoomaWord Pro</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

# --- 5. Icon ----------------------------------------------------------------
if [ -f "Resources/AppIcon.icns" ]; then
  cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

# --- 6. Sign (nested code first, then the bundle — never --deep) ------------
codesign "${SIGN_ARGS[@]}" "$APP/Contents/Frameworks/libLoomaWordLib.dylib"
codesign "${SIGN_ARGS[@]}" "$APP/Contents/MacOS/$APP_NAME"
codesign "${SIGN_ARGS[@]}" "$APP"

echo "✅ Berhasil dibangun: $APP (${VERSION} build ${BUILD_NUMBER})"
if [[ -z "${SIGN_ID:-}" ]]; then
  echo "⚠️  Ad-hoc signature: Gatekeeper akan memblokir app di Mac lain."
  echo "   Buka dengan right-click → Open, atau build ulang dengan SIGN_ID=\"Developer ID Application: ...\""
fi
