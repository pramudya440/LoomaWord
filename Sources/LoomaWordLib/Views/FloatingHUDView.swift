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
            // MARK: - Minimal Top Bar
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
                            .font(.system(size: 9, weight: .bold))
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
                .padding(.vertical, 3.5)
                .background(Color.secondary.opacity(0.09))
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
                    HStack(spacing: 3) {
                        Image(systemName: coordinator.selectedTone.icon)
                            .font(.system(size: 9))
                        Text(coordinator.selectedTone.rawValue)
                            .font(.system(size: 10.5, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 6.5))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
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

                // Action Buttons
                HStack(spacing: 6) {
                    // Copy button
                    if !coordinator.translatedText.isEmpty {
                        Button(action: {
                            coordinator.copyTranslation()
                            uiState.flashHUDCopied()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: uiState.hudCopiedNotice ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 10, weight: .semibold))
                                Text(uiState.hudCopiedNotice ? "Tersalin!" : "Salin")
                                    .font(.system(size: 10.5, weight: .semibold))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(uiState.hudCopiedNotice ? Color.green.opacity(0.2) : Color.accentColor.opacity(0.12))
                            .foregroundColor(uiState.hudCopiedNotice ? .green : .accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)

                        // Speak translation
                        Button(action: { coordinator.speakTranslation() }) {
                            Image(systemName: "speaker.wave.2")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(3)
                        }
                        .buttonStyle(.plain)
                        .help("Dengarkan pengucapan")
                    }

                    // Toggle source text preview (if needed)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            uiState.showSourceInHUD.toggle()
                        }
                    }) {
                        Image(systemName: uiState.showSourceInHUD ? "text.quote" : "text.bubble")
                            .font(.system(size: 10.5))
                            .foregroundColor(uiState.showSourceInHUD ? .accentColor : .secondary)
                            .padding(3)
                    }
                    .buttonStyle(.plain)
                    .help(uiState.showSourceInHUD ? "Sembunyikan teks asli" : "Lihat teks asli")

                    // Expand to full
                    Button(action: onExpandToFull) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(3)
                    }
                    .buttonStyle(.plain)
                    .help("Buka Workspace Penuh")

                    // More Options Menu
                    Menu {
                        Button(action: onExpandToFull) {
                            Label("Buka Workspace Dokumen", systemImage: "doc.text")
                        }
                        Button(action: {
                            onExpandToFull()
                            UIState.shared.selectedTab = 3
                        }) {
                            Label("Pengaturan...", systemImage: "gearshape")
                        }
                        Divider()
                        Button(action: {
                            coordinator.settings.showMenuBarIcon.toggle()
                            coordinator.saveSettings()
                            AppDelegate.shared.updateMenuBarIconVisibility(visible: coordinator.settings.showMenuBarIcon)
                        }) {
                            Label(coordinator.settings.showMenuBarIcon ? "Sembunyikan Icon Menu Bar" : "Tampilkan Icon Menu Bar",
                                  systemImage: coordinator.settings.showMenuBarIcon ? "eye.slash" : "eye")
                        }
                        Divider()
                        Button(role: .destructive, action: {
                            NSApp.terminate(nil)
                        }) {
                            Label("Keluar dari LoomaWord", systemImage: "power")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(3)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Opsi Tambahan")

                    // Close
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(3)
                    }
                    .buttonStyle(.plain)
                    .help("Tutup (Esc)")
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider()
                .opacity(0.3)

            // Optional Collapsed Source Preview (only if user clicks "Lihat teks asli")
            if uiState.showSourceInHUD {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Teks Asal:")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    Text(coordinator.sourceText.isEmpty ? "(Kosong)" : coordinator.sourceText)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(4)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.04))

                Divider()
                    .opacity(0.3)
            }

            // MARK: - Direct Pure Translation Display (Longer Vertically)
            VStack(alignment: .leading, spacing: 8) {
                if let err = coordinator.errorMessage {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        Text(coordinator.translatedText.isEmpty ? (coordinator.sourceText.isEmpty ? "Sorot teks lalu tekan ⌘+C+C untuk menerjemahkan..." : "Menerjemahkan...") : coordinator.translatedText)
                            .font(.system(size: 14.5, weight: .regular))
                            .foregroundColor(coordinator.translatedText.isEmpty ? .secondary.opacity(0.5) : .primary)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(minHeight: 180, maxHeight: 250)
                }

                // Compact Alternative suggestions
                if !coordinator.alternatives.isEmpty {
                    Divider()
                        .opacity(0.2)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            Text("Alternatif:")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(.secondary)

                            ForEach(coordinator.alternatives, id: \.self) { alt in
                                Button(action: {
                                    coordinator.translatedText = alt
                                }) {
                                    Text(alt)
                                        .font(.system(size: 11))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2.5)
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
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(width: 480)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 22, x: 0, y: 10)
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
                    .font(.system(size: 10.5, weight: .bold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 6.5))
                    .foregroundColor(.secondary)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
