import SwiftUI

public struct LanguagePickerView: View {
    let title: String
    @Binding var selectedCode: String
    let isSource: Bool
    let onSelectionChanged: () -> Void

    public init(title: String, selectedCode: Binding<String>, isSource: Bool = false, onSelectionChanged: @escaping () -> Void = {}) {
        self.title = title
        self._selectedCode = selectedCode
        self.isSource = isSource
        self.onSelectionChanged = onSelectionChanged
    }

    private var currentLanguage: Language {
        if isSource && selectedCode == "auto" {
            return Language.auto
        }
        return Language.find(code: selectedCode) ?? Language(code: selectedCode, name: selectedCode.uppercased(), nativeName: "", flag: "🌐")
    }

    public var body: some View {
        Menu {
            if isSource {
                Button(action: {
                    selectedCode = "auto"
                    onSelectionChanged()
                }) {
                    Text("\(Language.auto.flag)  \(Language.auto.name)")
                }
                Divider()
            }

            ForEach(Language.allLanguages) { lang in
                Button(action: {
                    selectedCode = lang.code
                    onSelectionChanged()
                }) {
                    HStack {
                        Text("\(lang.flag)  \(lang.name)")
                        if !lang.nativeName.isEmpty && lang.nativeName != lang.name {
                            Text("(\(lang.nativeName))")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(currentLanguage.flag)
                    .font(.system(size: 13))
                Text(currentLanguage.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
