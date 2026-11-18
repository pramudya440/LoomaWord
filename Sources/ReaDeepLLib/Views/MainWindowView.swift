import SwiftUI
import UniformTypeIdentifiers

public struct MainWindowView: View {
    @ObservedObject var coordinator: TranslationCoordinator
    @ObservedObject var uiState = UIState.shared

    public init(coordinator: TranslationCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: $uiState.selectedTab) {
                Label("Penerjemah", systemImage: "character.book.closed.fill")
                    .tag(0)
                Label("Kamus Istilah", systemImage: "text.book.closed.fill")
                    .tag(1)
                Label("Riwayat", systemImage: "clock.arrow.circlepath")
                    .tag(2)
                Label("Pengaturan", systemImage: "gearshape.fill")
                    .tag(3)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            switch uiState.selectedTab {
            case 0:
                WorkspaceTranslatorView(coordinator: coordinator)
            case 1:
                GlossaryView(coordinator: coordinator)
            case 2:
                HistoryView(coordinator: coordinator)
            case 3:
                SettingsView(coordinator: coordinator)
            default:
                EmptyView()
            }
        }
        .frame(minWidth: 800, minHeight: 520)
    }
}

struct WorkspaceTranslatorView: View {
    @ObservedObject var coordinator: TranslationCoordinator
    @ObservedObject var uiState = UIState.shared

    var body: some View {
        VStack(spacing: 0) {
            // Control Header
            HStack(spacing: 12) {
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
                    HStack(spacing: 6) {
                        Image(systemName: coordinator.selectedEngine.icon)
                            .foregroundColor(.accentColor)
                        Text(coordinator.selectedEngine.rawValue)
                            .font(.system(size: 12, weight: .bold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()

                // Languages
                HStack(spacing: 8) {
                    LanguagePickerView(
                        title: "Source",
                        selectedCode: $coordinator.sourceLang,
                        isSource: true
                    ) {
                        coordinator.triggerTranslation()
                    }

                    Button(action: { coordinator.swapLanguages() }) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 12, weight: .bold))
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

                // Document Import / Export
                Button(action: {
                    importFile()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.badge.plus")
                        Text("Buka Dokumen")
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.02))

            Divider()

            // Tone Selector
            ScrollView(.horizontal, showsIndicators: false) {
                ToneSelectorView(coordinator: coordinator)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .background(Color.primary.opacity(0.01))

            Divider()

            // Side by Side Editors
            HStack(spacing: 0) {
                // Left: Source
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Teks Asal")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)

                        Spacer()

                        if !coordinator.sourceText.isEmpty {
                            Text("\(coordinator.sourceText.count) karakter")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Button(action: {
                                coordinator.sourceText = ""
                                coordinator.triggerTranslation()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        Button(action: { coordinator.pasteAndTranslate() }) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .help("Tempel")

                        if !coordinator.sourceText.isEmpty {
                            Button(action: { coordinator.speakSource() }) {
                                Image(systemName: "speaker.wave.2")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .help("Dengarkan")
                        }
                    }

                    TextEditor(text: $coordinator.sourceText)
                        .font(.system(size: 15))
                        .scrollContentBackground(.hidden)
                        .onChange(of: coordinator.sourceText) {
                            if coordinator.settings.instantTranslateAsYouType {
                                coordinator.triggerTranslation(debounce: true)
                            }
                        }
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                // Right: Target
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        HStack(spacing: 6) {
                            Text("Hasil Terjemahan")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)

                            if coordinator.isTranslating {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                            }
                        }

                        Spacer()

                        if uiState.copiedNotice {
                            Text("Tersalin!")
                                .font(.caption.bold())
                                .foregroundColor(.green)
                        }

                        if !coordinator.translatedText.isEmpty {
                            Button(action: { coordinator.speakTranslation() }) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .help("Dengarkan")

                            Button(action: {
                                exportFile()
                            }) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .help("Ekspor ke Berkas")

                            Button(action: {
                                coordinator.copyTranslation()
                                uiState.flashCopied()
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
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                            .padding(.vertical, 4)
                        Spacer()
                    } else {
                        ScrollView {
                            Text(coordinator.translatedText.isEmpty ? (coordinator.sourceText.isEmpty ? "Ketikkan kalimat pada kolom kiri atau buka dokumen..." : "Menunggu hasil terjemahan...") : coordinator.translatedText)
                                .font(.system(size: 15))
                                .foregroundColor(coordinator.translatedText.isEmpty ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }

                    // Alternatives
                    if !coordinator.alternatives.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Saran Alternatif Frasa:")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)

                            ForEach(coordinator.alternatives, id: \.self) { alt in
                                Button(action: {
                                    coordinator.translatedText = alt
                                }) {
                                    Text("• \(alt)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.secondary.opacity(0.03))
            }

            Divider()

            // Status Bar
            HStack {
                Text(coordinator.statusMessage.isEmpty ? "Siap" : coordinator.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("ReaDeepL Pro Suite")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.02))
        }
    }

    private func importFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.plainText, .json, .utf8PlainText, UTType(filenameExtension: "md") ?? .plainText, UTType(filenameExtension: "srt") ?? .plainText]

        if panel.runModal() == .OK, let url = panel.url {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                coordinator.sourceText = content
                coordinator.triggerTranslation()
            }
        }
    }

    private func exportFile() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "translated_\(coordinator.targetLang).txt"
        panel.allowedContentTypes = [.plainText]

        if panel.runModal() == .OK, let url = panel.url {
            try? coordinator.translatedText.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
