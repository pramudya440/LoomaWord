#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "🔨 Menyiapkan build terbaru..."
./scripts/make-app.sh

echo "🛑 Menghentikan instance yang sedang berjalan..."
killall LoomaWord 2>/dev/null || true
killall ReaDeepL 2>/dev/null || true

echo "📁 Menyalin ke /Applications/LoomaWord.app..."
rm -rf /Applications/LoomaWord.app
rm -rf /Applications/ReaDeepL.app
cp -R dist/LoomaWord.app /Applications/

echo "⚙️ Mendaftarkan ke Login Items (Autorun saat Mac nyala)..."
osascript -e 'tell application "System Events" to delete (every login item whose name is "ReaDeepL")' 2>/dev/null || true
osascript -e 'tell application "System Events" to delete (every login item whose name is "LoomaWord")' 2>/dev/null || true
osascript -e 'tell application "System Events" to make login item at end with properties {name:"LoomaWord", path:"/Applications/LoomaWord.app", hidden:false}' 2>/dev/null || true
echo "   (Jika gagal otomatis, tambahkan manual: System Settings → General → Login Items)"

echo "🚀 Menjalankan LoomaWord dari /Applications..."
open /Applications/LoomaWord.app

echo "✅ Selesai! LoomaWord kini terpasang di /Applications dan otomatis berjalan (autorun) setiap kali Mac Anda dinyalakan."
