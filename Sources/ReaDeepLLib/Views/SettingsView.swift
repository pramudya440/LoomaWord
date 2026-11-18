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
                            TextField("Model (contoh: gemini-1.5-flash, gpt-4o-mini, llama3.2)", text: $coordinator.settings.aiModel)
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
                        Toggle("Terjemahkan instan saat mengetik (debounce 350ms)", isOn: $coordinator.settings.instantTranslateAsYouType)
                        Toggle("Putar suara pengucapan (TTS) otomatis setelah selesai terjemah", isOn: $coordinator.settings.playSpeechAfterTranslation)
                        Toggle("Jaga jendela HUD selalu di atas (Stay on top)", isOn: $coordinator.settings.stayOnTop)

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Pintasan DeepL Asli:")
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
                            Button("Buka Pengaturan Aksesibilitas") {
                                HotkeyManager.requestAccessibilityPermission()
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                        }
                    }
                    .padding(8)
                }

                HStack {
                    Spacer()
                    Button("Simpan Pengaturan") {
                        coordinator.saveSettings()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .onChange(of: coordinator.settings.aiProvider) {
            coordinator.settings.aiModel = coordinator.settings.aiProvider.defaultModel
            if coordinator.settings.aiProvider == .ollama {
                coordinator.settings.aiEndpoint = coordinator.settings.aiProvider.defaultEndpoint
            }
            coordinator.saveSettings()
        }
    }
}
