import SwiftUI
import AppKit

public struct FloatingHUDView: View {
    @ObservedObject var coordinator: TranslationCoordinator
    @ObservedObject var uiState = UIState.shared

    var onExpandToFull: () -> Void = {}
    var onClose: () -> Void = {}

    public init(
        coordinator: TranslationCoordinator,
        onExpandToFull: @escaping () -> Void = {},
        onClose: @escaping () -> Void = {}
    ) {
        self.coordinator = coordinator
        self.onExpandToFull = onExpandToFull
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header Bar
            HStack(spacing: 10) {
                // Engine Selector
                Menu {
                    ForEach(TranslationEngineType.allCases) { engine in
                        Button(action: {
                            coordinator.selectedEngine = engine
                            coordinator.triggerTranslation()
                        }) {
                            HStack {
                                Image(systemName: engine.icon)
                                Text(engine.rawValue)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: coordinator.selectedEngine.icon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.accentColor)
                        Text(coordinator.selectedEngine.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()

                // Languages Bar
                HStack(spacing: 6) {
                    LanguagePickerView(
                        title: "Source",
                        selectedCode: $coordinator.sourceLang,
                        isSource: true
                    ) {
                        coordinator.triggerTranslation()
                    }

                    Button(action: {
                        coordinator.swapLanguages()
                    }) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(coordinator.sourceLang == "auto" ? .secondary.opacity(0.4) : .primary)
                            .padding(6)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(coordinator.sourceLang == "auto")

                    LanguagePickerView(
                        title: "Target",
                        selectedCode: $coordinator.targetLang,
                        isSource: false
                    ) {
                        coordinator.triggerTranslation()
                    }
                }

                Spacer()

                // Window Control Buttons
                HStack(spacing: 6) {
                    Button(action: onExpandToFull) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(5)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Buka Workspace Lengkap")

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(5)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Tutup (Esc)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.03))

            Divider()

            // MARK: - Tone / Formality Pill Bar
            ScrollView(.horizontal, showsIndicators: false) {
                ToneSelectorView(coordinator: coordinator)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .background(Color.primary.opacity(0.015))

            Divider()

            // MARK: - Main Translation Content
            VStack(spacing: 0) {
                // Source Input Box
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Teks Asli")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        Spacer()

                        if !coordinator.sourceText.isEmpty {
                            Text("\(coordinator.sourceText.count) karakter")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)

                            Button(action: {
                                coordinator.sourceText = ""
                                coordinator.triggerTranslation()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                        }

                        Button(action: {
                            coordinator.pasteAndTranslate()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "doc.on.clipboard")
                                Text("Tempel")
                            }
                            .font(.system(size: 10))
                            .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)

                        if !coordinator.sourceText.isEmpty {
                            Button(action: {
                                coordinator.speakSource()
                            }) {
                                Image(systemName: "speaker.wave.2")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    TextEditor(text: $coordinator.sourceText)
                        .font(.system(size: 14))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 80, maxHeight: 120)
                        .onChange(of: coordinator.sourceText) {
                            if coordinator.settings.instantTranslateAsYouType {
                                coordinator.triggerTranslation(debounce: true)
                            }
                        }
                }
                .padding(14)

                Divider()

                // Translated Output Box
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        HStack(spacing: 6) {
                            Text("Terjemahan")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            if coordinator.isTranslating {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                            }
                        }

                        Spacer()

                        if uiState.hudCopiedNotice {
                            Text("Tersalin!")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.green)
                        }

                        if !coordinator.translatedText.isEmpty {
                            Button(action: {
                                coordinator.speakTranslation()
                            }) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Dengarkan Pengucapan")

                            Button(action: {
                                coordinator.copyTranslation()
                                uiState.flashHUDCopied()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "doc.on.doc.fill")
                                    Text("Salin")
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let err = coordinator.errorMessage {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    } else {
                        ScrollView {
                            Text(coordinator.translatedText.isEmpty ? (coordinator.sourceText.isEmpty ? "Mulai ketik atau tempel teks untuk menerjemahkan..." : "Menunggu terjemahan...") : coordinator.translatedText)
                                .font(.system(size: 14, weight: coordinator.translatedText.isEmpty ? .regular : .medium))
                                .foregroundColor(coordinator.translatedText.isEmpty ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(minHeight: 80, maxHeight: 120)
                    }

                    // Alternatives / Synonyms (DeepL Pro Style)
                    if !coordinator.alternatives.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Alternatif:")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(coordinator.alternatives, id: \.self) { alt in
                                        Button(action: {
                                            coordinator.translatedText = alt
                                        }) {
                                            Text(alt)
                                                .font(.system(size: 11))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(Color.secondary.opacity(0.1))
                                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(14)
                .background(Color.secondary.opacity(0.04))
            }

            Divider()

            // MARK: - Footer Status Bar
            HStack {
                if !coordinator.statusMessage.isEmpty {
                    Text(coordinator.statusMessage)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Text("⌘CC: Cepat • ⌥Space: Panggil")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("•")
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Esc: Tutup")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.02))
        }
        .frame(width: 580)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onAppear {
            if coordinator.settings.autoTranslateClipboard && coordinator.sourceText.isEmpty {
                coordinator.pasteAndTranslate()
            }
        }
    }
}
