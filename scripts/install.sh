#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "🔨 Menyiapkan build terbaru..."
./scripts/make-app.sh

echo "🛑 Menghentikan instance yang sedang berjalan..."
killall ReaDeepL 2>/dev/null || true

echo "📁 Menyalin ke /Applications/ReaDeepL.app..."
rm -rf /Applications/ReaDeepL.app
cp -R dist/ReaDeepL.app /Applications/

echo "⚙️ Mendaftarkan ke Login Items (Autorun saat Mac nyala)..."
osascript -e 'tell application "System Events" to delete (every login item whose name is "ReaDeepL")' 2>/dev/null || true
osascript -e 'tell application "System Events" to make login item at end with properties {name:"ReaDeepL", path:"/Applications/ReaDeepL.app", hidden:false}'

echo "🚀 Menjalankan ReaDeepL dari /Applications..."
open /Applications/ReaDeepL.app

echo "✅ Selesai! ReaDeepL kini terpasang di /Applications dan otomatis berjalan (autorun) setiap kali Mac Anda dinyalakan."
