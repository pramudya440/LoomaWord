import Foundation
import AppKit

@MainActor
public final class HotkeyManager {
    public static let shared = HotkeyManager()

    private var globalMonitor: Any?
    private var localMonitor: Any?

    private var lastCmdCTime: TimeInterval = 0
    private let doublePressThreshold: TimeInterval = 0.50 // 500ms

    public var onHotkeyPressed: (() -> Void)?
    public var onDoubleCmdCPressed: (() -> Void)?

    private init() {}

    public func startMonitoring() {
        stopMonitoring()

        // Local monitor (when app has focus)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if self.processKeyEvent(event: event) {
                return nil // swallow event
            }
            return event
        }

        // Global monitor (when outside app)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor [weak self] in
                _ = self?.processKeyEvent(event: event)
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

    private func processKeyEvent(event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // 1. Double ⌘ + C Detection (KeyCode 8 is 'C')
        if event.keyCode == 8 && (flags == .command || flags == [.command, .capsLock]) {
            let now = ProcessInfo.processInfo.systemUptime
            let diff = now - lastCmdCTime
            lastCmdCTime = now

            if diff > 0.05 && diff < doublePressThreshold {
                lastCmdCTime = 0
                onDoubleCmdCPressed?()
                return true
            }
            return false
        }

        // 2. Option + Space (KeyCode 49 is Space)
        if flags.contains(.option) && event.keyCode == 49 {
            onHotkeyPressed?()
            return true
        }

        // 3. Command + Shift + D (KeyCode 2 is 'D')
        if flags.contains(.command) && flags.contains(.shift) && event.keyCode == 2 {
            onHotkeyPressed?()
            return true
        }

        return false
    }

    public static func isAccessibilityTrusted() -> Bool {
        return AXIsProcessTrusted()
    }

    public static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
