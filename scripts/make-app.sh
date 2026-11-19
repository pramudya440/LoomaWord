#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="LoomaWord"
APP="dist/${APP_NAME}.app"
DEV=".dev"
STUB="$DEV/Launcher"

# 1. Build the dynamic library
SCRATCH="$HOME/Library/Caches/LoomaWordBuild"
echo "🔨 Building LoomaWordLib..."
swift build -c release --product LoomaWordLib --scratch-path "$SCRATCH"
LIB="$SCRATCH/release/libLoomaWordLib.dylib"

# 2. Build launcher stub once (or if source modified)
mkdir -p "$DEV"
if [ ! -f "$STUB" ] || [ Tools/Launcher/main.swift -nt "$STUB" ]; then
  echo "🔨 Compiling launcher stub..."
  swiftc -O Tools/Launcher/main.swift -o "$STUB"
  codesign --force --sign - "$STUB"
fi

# 3. Assemble .app bundle
echo "📦 Assembling ${APP_NAME}.app..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Resources"
cp "$STUB" "$APP/Contents/MacOS/$APP_NAME"
cp "$LIB" "$APP/Contents/Frameworks/libLoomaWordLib.dylib"
codesign --force --sign - "$APP/Contents/Frameworks/libLoomaWordLib.dylib"

# 4. Generate Info.plist
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>LoomaWord</string>
  <key>CFBundleIdentifier</key><string>com.pramudya.loomaword</string>
  <key>CFBundleName</key><string>LoomaWord</string>
  <key>CFBundleDisplayName</key><string>LoomaWord Pro</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

# 5. Copy custom original LoomaWord AppIcon
if [ -f "Resources/AppIcon.icns" ]; then
  cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

codesign --force --deep --sign - "$APP"
echo "✅ Berhasil dibangun: $APP"
