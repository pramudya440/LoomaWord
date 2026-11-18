import Foundation
import Combine

@MainActor
public final class UIState: ObservableObject {
    public static let shared = UIState()

    @Published public var copiedNotice: Bool = false
    @Published public var hudCopiedNotice: Bool = false
    @Published public var selectedTab: Int = 0
    @Published public var glossarySearchText: String = ""
    @Published public var glossaryNewSource: String = ""
    @Published public var glossaryNewTarget: String = ""
    @Published public var glossaryNewNotes: String = ""
    @Published public var isAddingGlossary: Bool = false
    @Published public var historySearchText: String = ""

    private init() {}

    public func flashCopied() {
        copiedNotice = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.copiedNotice = false
        }
    }

    public func flashHUDCopied() {
        hudCopiedNotice = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.hudCopiedNotice = false
        }
    }
}
