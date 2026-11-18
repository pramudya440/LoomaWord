#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="ReaDeepL"
APP="dist/${APP_NAME}.app"
DEV=".dev"
STUB="$DEV/Launcher"

# 1. Build the dynamic library
SCRATCH="$HOME/Library/Caches/ReaDeepLBuild"
echo "🔨 Building ReaDeepLLib..."
swift build -c release --product ReaDeepLLib --scratch-path "$SCRATCH"
LIB="$SCRATCH/release/libReaDeepLLib.dylib"

# 2. Build launcher stub once
mkdir -p "$DEV"
if [ ! -f "$STUB" ]; then
  echo "🔨 Compiling launcher stub..."
  swiftc -O Tools/Launcher/main.swift -o "$STUB"
  codesign --force --sign - "$STUB"
fi

# 3. Assemble .app bundle
echo "📦 Assembling ${APP_NAME}.app..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Resources"
cp "$STUB" "$APP/Contents/MacOS/$APP_NAME"
cp "$LIB" "$APP/Contents/Frameworks/libReaDeepLLib.dylib"
codesign --force --sign - "$APP/Contents/Frameworks/libReaDeepLLib.dylib"

# 4. Generate Info.plist
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>ReaDeepL</string>
  <key>CFBundleIdentifier</key><string>com.pramudya.readeepl</string>
  <key>CFBundleName</key><string>ReaDeepL</string>
  <key>CFBundleDisplayName</key><string>ReaDeepL Pro</string>
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

# Copy DeepL icon if present
if [ -f "/Applications/DeepL.app/Contents/Resources/AppIcon.icns" ]; then
  cp "/Applications/DeepL.app/Contents/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null || true
fi

codesign --force --deep --sign - "$APP"
echo "✅ Berhasil dibangun: $APP"
