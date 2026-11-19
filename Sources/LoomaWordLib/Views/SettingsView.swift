import SwiftUI

public struct SettingsView: View {
    @ObservedObject var coordinator: TranslationCoordinator

    public init(coordinator: TranslationCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Engine Preferences
                GroupBox(label: Label("Pilihan Engine Utama", systemImage: "sparkles")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Engine Standar", selection: $coordinator.selectedEngine) {
                            ForEach(TranslationEngineType.allCases) { engine in
                                Text(engine.rawValue).tag(engine)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: coordinator.selectedEngine) {
                            coordinator.saveSettings()
                        }

                        Text(coordinator.selectedEngine.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                }

                // MARK: - DeepL API
                GroupBox(label: Label("Konfigurasi DeepL API (Resmi)", systemImage: "bolt.shield.fill")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            SecureField("DeepL Auth Key (Free atau Pro)", text: $coordinator.settings.deepLAuthKey)
                                .textFieldStyle(.roundedBorder)

                            Toggle("Akun Pro", isOn: $coordinator.settings.deepLIsPro)
                                .toggleStyle(.checkbox)
                        }

                        Text("Masukkan kunci API resmi Anda jika memilikinya. Kunci DeepL Free biasanya berakhiran ':fx'.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        DisclosureGroup("Pengaturan Lanjutan DeepL (Endpoint Kustom)") {
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("Endpoint URL Kustom (misal proxy / DeepLX lokal)", text: $coordinator.settings.deepLCustomEndpoint)
                                    .textFieldStyle(.roundedBorder)
                                Text("Kosongkan untuk menggunakan server resmi DeepL secara otomatis.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(8)
                }

                // MARK: - AI Pro Engine
                GroupBox(label: Label("AI Pro Engine (Gemini / OpenAI / Ollama)", systemImage: "brain.head.profile")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Penyedia AI", selection: $coordinator.settings.aiProvider) {
                            ForEach(AIProvider.allCases) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        .pickerStyle(.menu)

                        if coordinator.settings.aiProvider != .ollama {
                            SecureField("API Key (\(coordinator.settings.aiProvider.rawValue))", text: $coordinator.settings.aiApiKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack {
                            TextField("Model (contoh: gemini-flash-latest, gpt-6-luna, llama3.2)", text: $coordinator.settings.aiModel)
                                .textFieldStyle(.roundedBorder)

                            Button("Default") {
                                coordinator.settings.aiModel = coordinator.settings.aiProvider.defaultModel
                            }
                            .buttonStyle(.bordered)
                        }

                        if coordinator.settings.aiProvider == .ollama || coordinator.settings.aiProvider == .custom {
                            TextField("Endpoint URL", text: $coordinator.settings.aiEndpoint)
                                .textFieldStyle(.roundedBorder)
                        }

                        Text("AI Pro memberikan penyesuaian gaya bahasa (Formal, Santai, Akademik, Bisnis) dan memahami konteks kalimat dengan sangat mendalam.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                }

                // MARK: - Perilaku & Pintasan
                GroupBox(label: Label("Perilaku & Tampilan", systemImage: "gearshape.2")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Otomatis terjemahkan isi clipboard saat jendela HUD dibuka", isOn: $coordinator.settings.autoTranslateClipboard)
                        Toggle("Terjemahan instan saat mengetik (jeda 700ms)", isOn: $coordinator.settings.instantTranslateAsYouType)
                        Toggle("Putar suara pengucapan (TTS) otomatis setelah selesai terjemah", isOn: $coordinator.settings.playSpeechAfterTranslation)
                        Toggle("Tampilkan icon LoomaWord di Menu Bar (Navbar)", isOn: Binding(
                            get: { coordinator.settings.showMenuBarIcon },
                            set: { newValue in
                                coordinator.settings.showMenuBarIcon = newValue
                                coordinator.saveSettings()
                                AppDelegate.shared.updateMenuBarIconVisibility(visible: newValue)
                            }
                        ))
                        if !coordinator.settings.showMenuBarIcon {
                            Text("💡 Icon disembunyikan dari navbar. LoomaWord tetap siap dipakai kapan saja via pintasan ⌥ + Space atau ⌘ + C + C.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Pintasan Cepat Instan:")
                                    .font(.subheadline.bold())
                                Spacer()
                                Text("⌘ + C + C (Tekan C 2x)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.15))
                                    .foregroundColor(.accentColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            Text("Sorot/blok teks apapun di aplikasi manapun (Safari, Chrome, PDF, VS Code, dll), lalu tekan ⌘+C dua kali dengan cepat. Panel terjemahan akan langsung muncul di dekat posisi kursor mouse Anda.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        HStack {
                            Text("Pintasan Panggil Manual:")
                                .font(.subheadline)
                            Spacer()
                            Text("⌥ + Space  atau  ⌘ + ⇧ + D")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        HStack {
                            Text("Izin Aksesibilitas macOS:")
                                .font(.subheadline)
                            Spacer()
                            Text("Tidak diperlukan — semua pintasan berjalan tanpa izin khusus.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                }

                // MARK: - Manajemen Aplikasi
                GroupBox(label: Label("Aplikasi", systemImage: "power.circle")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Keluar dari LoomaWord")
                                .font(.subheadline.bold())
                            Text("Tutup dan hentikan aplikasi LoomaWord sepenuhnya dari background.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive, action: {
                            NSApp.terminate(nil)
                        }) {
                            Label("Keluar Aplikasi", systemImage: "power")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(8)
                }

                HStack {
                    Spacer()
                    Label("Perubahan tersimpan otomatis", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .onChange(of: coordinator.settings.aiProvider) {
            let provider = coordinator.settings.aiProvider
            coordinator.settings.aiModel = provider.defaultModel
            // Reset stale endpoints: an Ollama URL left behind would silently send
            // OpenAI/Gemini requests to localhost.
            coordinator.settings.aiEndpoint = (provider == .ollama || provider == .custom)
                ? provider.defaultEndpoint
                : ""
            coordinator.saveSettings()
        }
    }
}
