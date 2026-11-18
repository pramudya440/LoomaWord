# ReaDeepL Pro — Native macOS Translation Suite

A super-fast, lightweight, native macOS translation app built with Swift and SwiftUI, designed to give you the full **DeepL Pro** experience with zero bloat and multi-engine flexibility.

---

## 🌟 Fitur Unggulan (Pro Experience)

### 1. Multi-Engine Translation Architecture
- **DeepL API (Official Free & Pro)**: Dukungan langsung untuk API Key DeepL resmi (baik Free `...:fx` maupun Pro). Dilengkapi fitur *Formality control*.
- **AI Pro Engine (Gemini / OpenAI / Ollama / DeepSeek)**: Menggunakan kecerdasan LLM untuk menghasilkan terjemahan yang sangat kontekstual, luwes, dan alami dengan instruksi tone yang akurat.
- **Instant Engine (Zero-Config Fallback)**: Langsung bekerja seketika tanpa perlu mendaftar atau memasukkan API key apapun sejak pertama kali dijalankan.
- **Smart Auto Engine**: Otomatis memilih engine terbaik yang tersedia (DeepL → AI Pro → Instant).

### 2. Pro Tone & Formality Control
Sesuaikan gaya bahasa terjemahan dengan 1 klik:
- 👔 **Formal (Baku)**: Bahasa resmi, sopan, tanpa bahasa gaul/slang. Sangat cocok untuk surat resmi, jurnal, dan dokumen legal.
- 💬 **Informal (Santai)**: Gaya percakapan luwes sehari-hari.
- 💼 **Business**: Bahasa korporat profesional, lugas, dan bernuansa komersial.
- 🎓 **Academic**: Register ilmiah dengan terminologi akademis presisi.
- 🎨 **Creative**: Adaptasi kontekstual idiomatis, tidak kaku atau harfiah.

### 3. Kamus Istilah Khusus (Custom Glossary)
- Tentukan aturan kosakata khusus Anda (misal: `pipeline` → `alur kerja`, `prompt engineering` → `rekayasa prompt`).
- AI dan DeepL akan mematuhi aturan istilah ini secara otomatis saat menerjemahkan kalimat utuh.
- Mendukung enable/disable per-istilah, pencarian, dan catatan konteks.

### 4. Floating Mini HUD & Menu Bar Quick Access
- **Global Hotkey**: Tekan `⌥ + Space` (Option + Spasi) atau `⌘ + ⇧ + D` dari aplikasi manapun untuk memunculkan panel translate melayang dengan efek frosted glass macOS.
- **Auto Clipboard Translate**: Saat panel HUD dibuka, teks yang baru saja Anda salin otomatis langsung diterjemahkan.
- **Saran Alternatif Frasa**: Klik kata alternatif untuk langsung mengganti frasa dalam terjemahan.
- **Pengucapan Suara (TTS)**: Dengarkan artikulasi suara bahasa asal maupun terjemahan secara native via `AVSpeechSynthesizer`.

### 5. Workspace Dokumen & Riwayat Terjemahan
- Mode jendela penuh (*Workspace*) untuk menerjemahkan paragraf panjang berdampingan.
- **Buka Dokumen**: Impor berkas teks `.txt`, `.md`, `.json`, `.srt` dan ekspor langsung hasilnya.
- **Riwayat Terjemahan**: Semua terjemahan tersimpan aman secara lokal di disk Anda (`~/Library/Application Support/ReaDeepL/`), dapat dicari, dan bebas dari pelacak/telemetri pihak ketiga.

---

## 🏗️ Struktur Arsitektur

Menggunakan pola arsitektur **Stable Launcher Stub + Rebuildable Dynamic Library** (mirip arsitektur aplikasi native performa tinggi macOS):

```text
rea deepL/
├── Package.swift                     # Definisi SwiftPM target
├── Sources/
│   ├── ReaDeepLLib/                 # Implementasi Utama (SwiftUI + AppKit)
│   │   ├── Models/                  # Language, Settings, Glossary, History, UIState
│   │   ├── Services/                # DeepLEngine, AIEngine, FastEngine, Coordinator, TTS, Hotkeys
│   │   ├── Views/                   # FloatingHUDView, MainWindowView, GlossaryView, HistoryView
│   │   └── App/                     # AppDelegate, status bar item & window controller
│   └── ReaDeepLLauncher/            # Entry point untuk swift run
├── Tools/
│   └── Launcher/main.swift          # Stub peluncur stabil (dlopen) agar izin macOS tetap awet
├── scripts/
│   ├── make-app.sh                  # Skrip kompilasi dan assembly bundle .app
│   └── run.sh                       # Skrip build & jalankan
└── dist/
    └── ReaDeepL.app                 # Aplikasi macOS mandiri siap pakai
```

---

## 🚀 Cara Menjalankan

### Membangun Aplikasi (`dist/ReaDeepL.app`):
```bash
./scripts/make-app.sh
```

### Memasang Permanen & Autorun saat Mac Dinyalakan:
```bash
./scripts/install.sh
```
Perintah ini akan memasang `ReaDeepL.app` ke `/Applications/` dan mendaftarkannya ke **Login Items macOS**, sehingga akan otomatis aktif setiap kali Mac dinyalakan tanpa perlu dibuka manual.

### Menjalankan Langsung (Testing):
```bash
./scripts/run.sh
```

---

## ⌨️ Pintasan Keyboard Default

| Pintasan | Fungsi |
| :--- | :--- |
| **`⌘ + C + C`** | **Pintasan DeepL Asli**: Blok teks di aplikasi manapun lalu tekan `⌘ + C` dua kali dengan cepat. Panel terjemahan instan akan muncul melayang tepat di posisi kursor mouse Anda! |
| `⌥ + Space` | Buka / Sembunyikan Floating HUD Translator secara manual dari mana saja |
| `⌘ + ⇧ + D` | Alternatif Hotkey Global untuk Floating HUD |
| `Esc` | Tutup panel Floating HUD |
| `⌘ + C` (di tombol Salin) | Salin hasil terjemahan langsung ke clipboard |
