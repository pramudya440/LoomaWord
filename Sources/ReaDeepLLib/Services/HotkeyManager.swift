import Foundation
import AppKit

public final class HotkeyManager {
    public static let shared = HotkeyManager()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    public var onHotkeyPressed: (() -> Void)?

    private init() {}

    public func startMonitoring() {
        stopMonitoring()

        // Local monitor (when app has focus)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.isTargetHotkey(event: event) == true {
                self?.onHotkeyPressed?()
                return nil // swallow event
            }
            return event
        }

        // Global monitor (when another app is focused)
        // Note: Needs Accessibility permission if listening globally
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.isTargetHotkey(event: event) == true {
                DispatchQueue.main.async {
                    self?.onHotkeyPressed?()
                }
            }
        }
    }

    public func stopMonitoring() {
        if let gm = globalMonitor {
            NSEvent.removeMonitor(gm)
            globalMonitor = nil
        }
        if let lm = localMonitor {
            NSEvent.removeMonitor(lm)
            localMonitor = nil
        }
    }

    private func isTargetHotkey(event: NSEvent) -> Bool {
        // Matches Option + Space (keyCode 49 is Space)
        if event.modifierFlags.contains(.option) && event.keyCode == 49 {
            return true
        }

        // Matches Command + Shift + D (keyCode 2 is 'D')
        if event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) && event.keyCode == 2 {
            return true
        }

        return false
    }
}
