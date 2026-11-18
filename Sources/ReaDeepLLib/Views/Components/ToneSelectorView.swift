import SwiftUI

public struct ToneSelectorView: View {
    @ObservedObject var coordinator: TranslationCoordinator

    public init(coordinator: TranslationCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(TranslationTone.allCases) { tone in
                Button(action: {
                    coordinator.selectedTone = tone
                    coordinator.triggerTranslation()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: tone.icon)
                            .font(.system(size: 10, weight: .semibold))
                        Text(tone.rawValue)
                            .font(.system(size: 11, weight: coordinator.selectedTone == tone ? .bold : .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        coordinator.selectedTone == tone
                            ? Color.accentColor.opacity(0.2)
                            : Color.secondary.opacity(0.1)
                    )
                    .foregroundColor(
                        coordinator.selectedTone == tone
                            ? .accentColor
                            : .secondary
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(
                                coordinator.selectedTone == tone ? Color.accentColor.opacity(0.4) : Color.clear,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
