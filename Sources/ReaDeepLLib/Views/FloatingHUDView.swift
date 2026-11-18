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
            // MARK: - Ultra-Minimalist Header Bar
            HStack(spacing: 8) {
                // Compact Language Selector
                HStack(spacing: 4) {
                    CompactLanguageMenu(
                        code: $coordinator.sourceLang,
                        isSource: true
                    ) {
                        coordinator.triggerTranslation()
                    }

                    Button(action: { coordinator.swapLanguages() }) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(coordinator.sourceLang == "auto" ? .secondary.opacity(0.3) : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(coordinator.sourceLang == "auto")

                    CompactLanguageMenu(
                        code: $coordinator.targetLang,
                        isSource: false
                    ) {
                        coordinator.triggerTranslation()
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())

                // Compact Tone Menu
                Menu {
                    ForEach(TranslationTone.allCases) { tone in
                        Button(action: {
                            coordinator.selectedTone = tone
                            coordinator.triggerTranslation()
                        }) {
                            HStack {
                                Image(systemName: tone.icon)
                                Text(tone.rawValue)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: coordinator.selectedTone.icon)
                            .font(.system(size: 9))
                        Text(coordinator.selectedTone.rawValue)
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(coordinator.selectedTone == .standard ? Color.secondary.opacity(0.08) : Color.accentColor.opacity(0.15))
                    .foregroundColor(coordinator.selectedTone == .standard ? .secondary : .accentColor)
                    .clipShape(Capsule())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()

                if coordinator.isTranslating {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                }

                // Window Actions (Expand & Close)
                HStack(spacing: 4) {
                    Button(action: onExpandToFull) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    .help("Buka Workspace Penuh")

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    .help("Tutup (Esc)")
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()
                .opacity(0.4)

            // MARK: - Translation Content
            VStack(spacing: 0) {
                // Source Input
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Spacer()
                        if !coordinator.sourceText.isEmpty {
                            Button(action: {
                                coordinator.sourceText = ""
                                coordinator.triggerTranslation()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                            .buttonStyle(.plain)

                            Button(action: { coordinator.speakSource() }) {
                                Image(systemName: "speaker.wave.2")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    TextEditor(text: $coordinator.sourceText)
                        .font(.system(size: 13.5))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 65, maxHeight: 95)
                        .onChange(of: coordinator.sourceText) {
                            if coordinator.settings.instantTranslateAsYouType {
                                coordinator.triggerTranslation(debounce: true)
                            }
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()
                    .opacity(0.4)

                // Translated Output
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Spacer()
                        if uiState.hudCopiedNotice {
                            Text("Tersalin!")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.green)
                                .transition(.opacity)
                        }

                        if !coordinator.translatedText.isEmpty {
                            Button(action: { coordinator.speakTranslation() }) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                coordinator.copyTranslation()
                                uiState.flashHUDCopied()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "doc.on.doc.fill")
                                    Text("Salin")
                                }
                                .font(.system(size: 10.5, weight: .semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let err = coordinator.errorMessage {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .padding(.vertical, 4)
                    } else {
                        ScrollView {
                            Text(coordinator.translatedText.isEmpty ? (coordinator.sourceText.isEmpty ? "Hasil terjemahan akan muncul di sini..." : "Menerjemahkan...") : coordinator.translatedText)
                                .font(.system(size: 14, weight: coordinator.translatedText.isEmpty ? .regular : .medium))
                                .foregroundColor(coordinator.translatedText.isEmpty ? .secondary.opacity(0.5) : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(minHeight: 70, maxHeight: 110)
                    }

                    // Compact Alternative chips
                    if !coordinator.alternatives.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 5) {
                                ForEach(coordinator.alternatives, id: \.self) { alt in
                                    Button(action: {
                                        coordinator.translatedText = alt
                                    }) {
                                        Text(alt)
                                            .font(.system(size: 10.5))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.08))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.03))
            }
        }
        .frame(width: 480)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 8)
    }
}

// MARK: - Compact Language Menu
struct CompactLanguageMenu: View {
    @Binding var code: String
    let isSource: Bool
    let onSelection: () -> Void

    private var currentLang: Language {
        if isSource && code == "auto" {
            return Language.auto
        }
        return Language.find(code: code) ?? Language(code: code, name: code.uppercased(), nativeName: "", flag: "🌐")
    }

    var body: some View {
        Menu {
            if isSource {
                Button(action: {
                    code = "auto"
                    onSelection()
                }) {
                    Text("\(Language.auto.flag)  \(Language.auto.name)")
                }
                Divider()
            }

            ForEach(Language.allLanguages) { lang in
                Button(action: {
                    code = lang.code
                    onSelection()
                }) {
                    Text("\(lang.flag)  \(lang.name)")
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(currentLang.flag)
                    .font(.system(size: 11))
                Text(currentLang.code.uppercased())
                    .font(.system(size: 11, weight: .bold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 7))
                    .foregroundColor(.secondary)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
