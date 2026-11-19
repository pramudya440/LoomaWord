import SwiftUI

public struct HistoryView: View {
    @ObservedObject var coordinator: TranslationCoordinator
    @ObservedObject var uiState = UIState.shared

    public init(coordinator: TranslationCoordinator) {
        self.coordinator = coordinator
    }

    private var filteredHistory: [TranslationHistoryItem] {
        if uiState.historySearchText.isEmpty {
            return coordinator.history
        }
        return coordinator.history.filter {
            $0.sourceText.localizedCaseInsensitiveContains(uiState.historySearchText) ||
            $0.translatedText.localizedCaseInsensitiveContains(uiState.historySearchText) ||
            $0.engineUsed.localizedCaseInsensitiveContains(uiState.historySearchText)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Riwayat Terjemahan")
                        .font(.headline)
                    Text("\(coordinator.history.count) terjemahan tersimpan lokal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !coordinator.history.isEmpty {
                    Button(action: {
                        coordinator.history.removeAll()
                        StorageManager.shared.clearHistory()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Hapus Semua")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()

            Divider()

            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Cari di riwayat...", text: $uiState.historySearchText)
                    .textFieldStyle(.plain)
                if !uiState.historySearchText.isEmpty {
                    Button(action: { uiState.historySearchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            .padding(.vertical, 8)

            if filteredHistory.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(uiState.historySearchText.isEmpty ? "Belum ada riwayat terjemahan" : "Tidak ada hasil pencarian")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(filteredHistory) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(item.sourceLang.uppercased()) → \(item.targetLang.uppercased())")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(Capsule())

                                Text("• \(item.engineUsed) (\(item.toneUsed))")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text(item.timestamp, style: .time)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)

                                Button(action: {
                                    coordinator.sourceText = item.sourceText
                                    coordinator.translatedText = item.translatedText
                                    coordinator.sourceLang = item.sourceLang
                                    coordinator.targetLang = item.targetLang
                                }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 11))
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                                .help("Gunakan kembali teks ini")
                            }

                            Text(item.sourceText)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(2)

                            Text(item.translatedText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(3)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}
