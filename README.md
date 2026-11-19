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

> DeepL's `formality` parameter only exists for some target languages (German, French, Japanese, … — not Indonesian or Korean). LoomaWord sends `prefer_more` / `prefer_less` only when a tone is chosen, and never sends the parameter for the Standard tone, so translations work for every target language.

### 3. Custom Glossary
- Define strict domain-specific vocabulary rules (e.g. `pipeline` → `workflow`, `prompt engineering` → `prompt design`).
- Glossary rules are applied by the **AI Pro Engine**, filtered to the active language pair (an `en → id` rule never leaks into another pair).
- The **Instant Engine** does not apply glossary rules; the **DeepL API** uses DeepL's own glossary system, which requires creating the glossary on the DeepL website.
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
- **Document Import/Export**: Open `.txt` and `.md` files (up to 100 KB) and export translated results directly. Large texts are automatically split into paragraph-sized chunks before sending.
- **Translation Cache**: Re-translating identical text (same languages, engine, tone and glossary) is served from an in-memory LRU cache instead of re-billing your API quota.
- **Local Storage, Remote Processing**: Settings, glossaries and history never leave your Mac (`~/Library/Application Support/LoomaWord/`) and there is zero telemetry — but the text you translate **is** sent to the engine you chose (DeepL, Google, Gemini/OpenAI/Ollama, MyMemory).

---

## 🔐 Privacy & Data Flow

| Data | Where it goes |
| :--- | :--- |
| Settings, API keys, glossary, history | Stored **locally** only (plaintext JSON in `~/Library/Application Support/LoomaWord/`) |
| Text you translate | Sent to the **selected engine's** server: DeepL (`api.deepl.com` / `api-free.deepl.com`), Google (`translate.googleapis.com`), MyMemory, or your configured LLM provider |
| Telemetry / analytics | **None** |

> ⚠️ The Instant Engine uses Google's undocumented endpoint and MyMemory as a fallback. If you need guaranteed privacy, configure the official DeepL API or a local Ollama model.

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

### Requirements
- macOS 14.0 (Sonoma) or later — the app is a **universal binary** (Apple Silicon + Intel).
- Optional: a DeepL API key, or an AI provider key (Gemini / OpenAI / DeepSeek), or a local Ollama server. Without any key the Instant Engine works out of the box.

### Option 1: Direct Download (Pre-built)
1. Download **[LoomaWord.dmg](https://github.com/pramudya440/LoomaWord/releases/latest/download/LoomaWord.dmg)**.
2. Open the disk image and drag **LoomaWord** into your **Applications** folder.
3. Launch LoomaWord.

#### ⚠️ "App can't be opened" / Gatekeeper warning
Release builds are signed with your Developer ID when one is configured. If the build you downloaded is **ad-hoc signed** (no Developer ID), macOS Gatekeeper will refuse to open it. To open it anyway:

```bash
xattr -dr com.apple.quarantine /Applications/LoomaWord.app
```

or: right-click (Control-click) **LoomaWord.app** → **Open** → **Open**.

**No Accessibility permission is required** — `⌘ + C + C`, `⌥ + Space` and `⌘ + ⇧ + D` all work without any TCC prompts.

### Option 2: Build from Source
```bash
# Clone the repository
git clone https://github.com/pramudya440/LoomaWord.git
cd LoomaWord

# Build the .app bundle (universal, ad-hoc signed)
./scripts/make-app.sh

# Or build a distributable, notarization-ready bundle:
SIGN_ID="Developer ID Application: Your Name (TEAMID)" ./scripts/make-app.sh

# Or install directly to /Applications with autorun on boot:
./scripts/install.sh

# Run the unit tests (requires Xcode / the XCTest toolchain)
swift test
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

---

## 🧪 Testing & CI

```bash
swift build          # build everything
swift test           # run the unit tests (requires Xcode's XCTest toolchain)
```

Covered by tests: text sanitizing (percent/HTML entities), URL encoding (`&`, `+`, `?`), DeepL target-language and formality mapping, request body construction, tolerant `settings.json` decoding + retired-model migration, glossary language-pair filtering, and document chunking.

GitHub Actions (`.github/workflows/release.yml`) builds and tests every push, and publishes `LoomaWord.dmg` as a release asset when you push a version tag:

```bash
git tag v1.1.0
git push origin v1.1.0
```

---

## 📄 License

LoomaWord is released under the [MIT License](LICENSE).
