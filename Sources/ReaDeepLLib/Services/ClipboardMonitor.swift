import Foundation
import AppKit

@MainActor
public final class ClipboardMonitor {
    public static let shared = ClipboardMonitor()

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var lastChangeTime: TimeInterval = 0
    private let doubleCopyThreshold: TimeInterval = 0.55 // 550ms

    public var onDoubleCopy: ((String) -> Void)?

    private init() {}

    public func start() {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount

        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkPasteboard()
            }
        }
        if let t = timer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkPasteboard() {
        let currentCount = NSPasteboard.general.changeCount
        if currentCount != lastChangeCount {
            lastChangeCount = currentCount
            let now = ProcessInfo.processInfo.systemUptime
            let diff = now - lastChangeTime
            lastChangeTime = now

            // If copied twice within threshold, trigger double ⌘+C translation!
            if diff > 0.04 && diff < doubleCopyThreshold {
                lastChangeTime = 0 // reset so 3rd copy doesn't re-trigger immediately
                if let str = NSPasteboard.general.string(forType: .string) {
                    let clean = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty {
                        onDoubleCopy?(clean)
                    }
                }
            }
        }
    }
}
