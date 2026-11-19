# LoomaWord Pro — Native macOS Translation Suite

An ultra-fast, lightweight native macOS translation suite built with Swift and SwiftUI, designed to deliver a seamless, high-performance translation experience with zero bloat and multi-engine flexibility.

**[⬇️ Download LoomaWord.dmg (Latest Release)](https://github.com/pramudya440/LoomaWord/releases/latest/download/LoomaWord.dmg)**

---

## 🌟 Key Features

### 1. Multi-Engine Translation Architecture
- **DeepL API (Official Free & Pro)**: Direct support for official DeepL API keys (Free `:fx` or Pro accounts) with native *Formality control*.
- **AI Pro Engine (Gemini / OpenAI / Ollama / DeepSeek)**: Context-aware translations powered by LLMs with accurate tone instruction and natural language nuance.
- **Instant Engine (Zero-Config Fallback)**: Works instantly out of the box without requiring any API keys or registration.
- **Smart Auto Engine**: Automatically selects the best available translation engine (DeepL → AI Pro → Instant).

### 2. Pro Tone & Formality Control
Customize translation tone with one click:
- 👔 **Formal**: Standard, polite language without colloquialisms. Ideal for official correspondence, legal papers, and scholarly works.
- 💬 **Informal**: Natural, conversational phrasing for casual daily dialogues.
- 💼 **Business**: Crisp, executive corporate language with commercial precision.
- 🎓 **Academic**: Scholarly register with precise academic terminology.
- 🎨 **Creative**: Idiomatic and contextual adaptation that preserves figurative meaning.

### 3. Custom Glossary
- Define strict domain-specific vocabulary rules (e.g. `pipeline` → `workflow`, `prompt engineering` → `prompt design`).
- Both AI models and DeepL automatically adhere to your customized term definitions.
- Supports per-term toggling, searching, and context notes.

### 4. Floating Mini HUD & Menu Bar Quick Access
- **Instant Double-Copy (`⌘ + C + C`)**: Highlight text in any application (browser, PDF, IDE) and press `⌘ + C` twice quickly. The floating HUD pops up directly beside your mouse cursor with the translated text.
- **Global Hotkey**: Press `⌥ + Space` (Option + Space) or `⌘ + ⇧ + D` from anywhere to toggle the frosted-glass translation HUD.
- **Auto Clipboard Translate**: Automatically translates recently copied text upon opening the HUD.
- **Alternative Phrase Suggestions**: Click alternative word choices to substitute phrases on the fly.
- **Native Speech Synthesis (TTS)**: Listen to native pronunciation for source and translated text via `AVSpeechSynthesizer`.
- **Customizable Menu Bar**: Easily hide or toggle the status icon, or drag it off with `⌘ + Drag`.

### 5. Document Workspace & Translation History
- **Full-Screen Workspace**: Side-by-side split view designed for translating long documents and articles.
- **Document Import/Export**: Open `.txt`, `.md`, `.json`, and `.srt` files and export translated results directly.
- **100% Local & Private**: All settings, glossaries, and translation history are stored locally on your Mac (`~/Library/Application Support/LoomaWord/`) with zero third-party telemetry.

---

## 🏗️ Architecture

LoomaWord uses a high-performance **Stable Launcher Stub + Rebuildable Dynamic Library** design:

```text
LoomaWord/
├── Package.swift                     # Swift Package Manager manifest
├── Sources/
│   ├── LoomaWordLib/                # Core implementation (SwiftUI + AppKit)
│   │   ├── Models/                  # Language, Settings, Glossary, History, UIState
│   │   ├── Services/                # DeepLEngine, AIEngine, FastEngine, Coordinator, TTS, Hotkeys
│   │   ├── Views/                   # FloatingHUDView, MainWindowView, GlossaryView, HistoryView
│   │   └── App/                     # AppDelegate, status bar item & window controller
│   └── LoomaWordLauncher/           # Entry point for swift run
├── Tools/
│   ├── Launcher/main.swift          # Stable launcher stub (dlopen) preserving macOS permissions
│   └── IconGenerator/               # Vector icon generation pipeline
├── scripts/
│   ├── make-app.sh                  # Application compilation & bundle assembly script
│   ├── make-dmg.sh                  # Distributable disk image (.dmg) packager
│   ├── install.sh                   # Install to /Applications & macOS Login Items
│   └── run.sh                       # Quick build & test runner
└── dist/
    ├── LoomaWord.app                # Standalone macOS application bundle
    └── LoomaWord.dmg                # Standalone disk image installer
```

---

## 🚀 Getting Started

### Option 1: Direct Download (Pre-built)
1. Download **[LoomaWord.dmg](https://github.com/pramudya440/LoomaWord/releases/latest/download/LoomaWord.dmg)**.
2. Open the disk image and drag **LoomaWord** into your **Applications** folder.
3. Launch LoomaWord. Grant Accessibility permission when prompted to enable the `⌘ + C + C` double-copy shortcut.

### Option 2: Build from Source
```bash
# Clone the repository
git clone https://github.com/pramudya440/LoomaWord.git
cd LoomaWord

# Build the .app bundle
./scripts/make-app.sh

# Or install directly to /Applications with autorun on boot:
./scripts/install.sh
```

---

## ⌨️ Default Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| **`⌘ + C + C`** | **Quick Translate**: Select text anywhere and press `⌘ + C` twice quickly. The HUD appears next to your cursor. |
| `⌥ + Space` | Toggle the Floating HUD Translator from any window |
| `⌘ + ⇧ + D` | Alternative Global Hotkey |
| `Esc` | Close / Dismiss the Floating HUD |
| `⌘ + C` (on Copy button) | Copy translated text directly to clipboard |
