import Foundation
import AppKit

/// Detects the "double ⌘+C" gesture by polling the pasteboard.
///
/// This is the *only* double-copy detector: it needs no Accessibility permission and
/// works in every app. `HotkeyManager` deliberately does not watch keyDown for this.
@MainActor
public final class ClipboardMonitor {
    public static let shared = ClipboardMonitor()

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var lastChangeTime: TimeInterval = 0
    private let doubleCopyThreshold: TimeInterval = 0.55 // 550ms
    private let pollInterval: TimeInterval = 0.15         // 150ms

    /// Number of upcoming pasteboard changes to ignore (our own copies).
    private var ignoreChanges: Int = 0

    public var onDoubleCopy: ((String) -> Void)?

    private init() {}

    public func start() {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount
        lastChangeTime = 0

        let t = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            // Timer is scheduled on the main run loop, so we are already on MainActor.
            MainActor.assumeIsolated {
                self?.checkPasteboard()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Call before LoomaWord writes to the pasteboard so its own "copy" doesn't
    /// count as one half of a double-copy gesture.
    public func ignoreNextChange() {
        ignoreChanges += 1
        lastChangeTime = 0
    }

    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }

        lastChangeCount = currentCount

        if ignoreChanges > 0 {
            ignoreChanges -= 1
            lastChangeTime = 0
            return
        }

        // Privacy: never auto-translate passwords or transient drag data.
        if let types = pasteboard.types,
           types.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")) ||
           types.contains(NSPasteboard.PasteboardType("org.nspasteboard.TransientType")) {
            lastChangeTime = 0
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        let diff = now - lastChangeTime
        lastChangeTime = now

        // Two changes within the threshold = double ⌘+C.
        if diff > 0.04 && diff < doubleCopyThreshold {
            lastChangeTime = 0 // reset so a 3rd copy doesn't re-trigger immediately
            if let str = pasteboard.string(forType: .string) {
                let clean = str.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty {
                    onDoubleCopy?(clean)
                }
            }
        }
    }
}
