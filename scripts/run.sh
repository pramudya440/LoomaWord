#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

# Kill existing instance if running
killall ReaDeepL 2>/dev/null || true

# Rebuild if needed
./scripts/make-app.sh

echo "🚀 Menjalankan ReaDeepL Pro..."
open "dist/ReaDeepL.app"
