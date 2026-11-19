import SwiftUI

public struct GlossaryView: View {
    @ObservedObject var coordinator: TranslationCoordinator
    @ObservedObject var uiState = UIState.shared

    public init(coordinator: TranslationCoordinator) {
        self.coordinator = coordinator
    }

    private var filteredItems: [GlossaryItem] {
        if uiState.glossarySearchText.isEmpty {
            return coordinator.glossary
        }
        return coordinator.glossary.filter {
            $0.sourceTerm.localizedCaseInsensitiveContains(uiState.glossarySearchText) ||
            $0.targetTerm.localizedCaseInsensitiveContains(uiState.glossarySearchText) ||
            $0.notes.localizedCaseInsensitiveContains(uiState.glossarySearchText)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kamus Istilah Khusus (Glossary)")
                        .font(.headline)
                    Text("Tentukan istilah teknis atau kosakata khusus agar selalu diterjemahkan sesuai aturan Anda.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    withAnimation { uiState.isAddingGlossary.toggle() }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: uiState.isAddingGlossary ? "xmark" : "plus")
                        Text(uiState.isAddingGlossary ? "Batal" : "Tambah Istilah")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Add Form
            if uiState.isAddingGlossary {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tambah Istilah Baru")
                        .font(.subheadline.bold())

                    HStack(spacing: 8) {
                        TextField("Istilah Asal (e.g. prompt engineering)", text: $uiState.glossaryNewSource)
                            .textFieldStyle(.roundedBorder)

                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)

                        TextField("Istilah Target (e.g. rekayasa prompt)", text: $uiState.glossaryNewTarget)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        TextField("Catatan / Konteks (opsional)", text: $uiState.glossaryNewNotes)
                            .textFieldStyle(.roundedBorder)

                        Button("Simpan") {
                            guard !uiState.glossaryNewSource.trimmingCharacters(in: .whitespaces).isEmpty,
                                  !uiState.glossaryNewTarget.trimmingCharacters(in: .whitespaces).isEmpty else { return }

                            let item = GlossaryItem(
                                sourceTerm: uiState.glossaryNewSource.trimmingCharacters(in: .whitespaces),
                                targetTerm: uiState.glossaryNewTarget.trimmingCharacters(in: .whitespaces),
                                sourceLang: coordinator.sourceLang == "auto" ? "en" : coordinator.sourceLang,
                                targetLang: coordinator.targetLang,
                                isEnabled: true,
                                notes: uiState.glossaryNewNotes.trimmingCharacters(in: .whitespaces)
                            )
                            coordinator.glossary.insert(item, at: 0)
                            coordinator.saveGlossary()

                            uiState.glossaryNewSource = ""
                            uiState.glossaryNewTarget = ""
                            uiState.glossaryNewNotes = ""
                            uiState.isAddingGlossary = false
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(uiState.glossaryNewSource.isEmpty || uiState.glossaryNewTarget.isEmpty)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.06))
                Divider()
            }

            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Cari istilah...", text: $uiState.glossarySearchText)
                    .textFieldStyle(.plain)
                if !uiState.glossarySearchText.isEmpty {
                    Button(action: { uiState.glossarySearchText = "" }) {
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

            // Items List
            List {
                ForEach(filteredItems) { item in
                    HStack(alignment: .center, spacing: 12) {
                        Toggle("", isOn: Binding(
                            get: { item.isEnabled },
                            set: { val in
                                if let idx = coordinator.glossary.firstIndex(where: { $0.id == item.id }) {
                                    coordinator.glossary[idx].isEnabled = val
                                    coordinator.saveGlossary()
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(item.sourceTerm)
                                    .font(.system(size: 13, weight: .bold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(item.targetTerm)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.accentColor)
                            }

                            if !item.notes.isEmpty {
                                Text(item.notes)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Button(action: {
                            coordinator.glossary.removeAll { $0.id == item.id }
                            coordinator.saveGlossary()
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)
        }
    }
}
