# Changelog

All notable changes to LoomaWord are documented here.

## [1.1.0] — Unreleased

### Fixed
- **DeepL always failed for Indonesian (and other non-formality targets).** The engine
  sent `formality=default` on every request; DeepL rejects the parameter for languages
  that don't support it. Now the parameter is omitted for the Standard tone and
  `prefer_more` / `prefer_less` are used otherwise (accepted for all targets).
- **DeepL language codes**: `zh-TW` → `ZH-HANT`, `pt` → `PT`; unsupported targets
  (`th`, `hi`) now produce a clear error instead of a raw HTTP failure.
- **Retired AI model IDs**: default Gemini model was `gemini-1.5-flash` (shut down in
  Sept 2025). Defaults are now `gemini-flash-latest`, `gpt-6-luna`, `llama3.2`,
  `deepseek-chat`, and stored settings are migrated off retired IDs on load.
- **Settings could be silently reset.** `AppSettings` now uses a tolerant decoder:
  every missing key falls back to its default instead of failing the whole file, so
  future schema changes can no longer wipe stored API keys. Corrupt files are backed
  up (`settings.json.corrupt-<timestamp>.json`) instead of overwritten, and all writes
  are atomic.
- **Spinner could spin forever** after a request was cancelled (e.g. clearing the text
  box mid-request). Requests now carry a generation token; only the newest request may
  touch UI state.
- **Instant Engine URL corruption**: `&`, `+`, `=` and `?` in the source text were not
  escaped, so `R&D` split the query and `C++` became `C  `. URLs are now built with
  explicit percent-encoding.
- **Sanitizer damaged legitimate text**: `"100%20off"` → `"100 off"` and HTML `&amp;`
  was decoded before `&lt;`. Sanitizing is now a single shared pass
  (`TextSanitizer`) with an all-or-nothing percent heuristic and correct entity order.
- **Double-trigger of the quick-translate HUD**: both the keyDown monitor and the
  pasteboard monitor detected `⌘ + C + C`, so the request fired twice when the
  Accessibility permission was granted. Detection now lives only in `ClipboardMonitor`.
- **Copy inside the app re-triggered quick-translate** (the app's own pasteboard write
  counted as a copy). Own writes are now ignored.
- Passwords and transient pasteboard content (`.ConcealedType` / `.TransientType`)
  are never auto-translated.
- **Stale AI endpoint**: switching provider (e.g. Ollama → OpenAI) kept the old
  localhost endpoint and silently sent requests there.
- TTS voice selection now covers `pt`, `nl`, `pl`, `sv`, `da`, `fi`, `cs`, `el`, `tr`,
  `vi`, `th`, `hi`, `uk`, … via locale mapping + installed-voice matching instead of a
  12-entry hard-coded switch.
- Glossary rules are now filtered by language pair instead of applying every rule to
  every request.
- Clearing history required no confirmation and bypassed the in-memory state.
- Esc on the HUD now also tears down the outside-click monitors.
- Double-clicking the app while it is running reopens the workspace
  (`applicationShouldHandleReopen`).
- Pending settings/history writes are flushed on quit.

### Changed
- `⌥ + Space` / `⌘ + ⇧ + D` moved to Carbon `RegisterEventHotKey`: no Accessibility
  permission needed, and the keystroke is consumed instead of leaking to other apps.
- Instant-as-you-type debounce raised from 350 ms → 700 ms; large texts are chunked
  (≈1200 chars for the Instant Engine, ≈4000 otherwise) before being sent.
- Translation results are cached (LRU, 100 entries) keyed by text, languages, engine,
  tone and glossary; cache hits are free and shown as `cache` in the status bar.
- History is held in memory and written to disk debounced instead of rewriting the
  whole file on every keystroke.
- HTTP layer now has an explicit timeout and retries 429/5xx with exponential backoff
  (honouring `Retry-After`); 4xx client errors are never retried and error bodies are
  truncated for readability.
- Settings autosave on every change (no more "Simpan Pengaturan" button to forget).
- Document import reads files off the main thread, caps them at 100 KB, and only
  offers `.txt` / `.md` (raw `.json` / `.srt` translation corrupted keys and
  timestamps).
- `scripts/make-app.sh` now builds a **universal** (arm64 + x86_64) binary, injects
  the version from `VERSION` / the latest git tag and the build number from the commit
  count, and supports `SIGN_ID` for Developer ID + hardened runtime signing.

### Added
- **MIT `LICENSE`**.
- Unit test target (`swift test`) covering sanitizing, URL encoding, DeepL mapping,
  settings decoding/migration, glossary filtering and chunking.
- GitHub Actions workflow: build + test on every push, DMG release asset on tags.
- README: privacy/data-flow section, Gatekeeper workaround, requirements, testing docs.

### Removed
- Dead settings (`globalHotkeyString`, `stayOnTop`, `soundEffects`) and the unused
  `isFavorite` history field (history files from older versions still load).
- Accessibility-permission UI — no feature requires it any more.
