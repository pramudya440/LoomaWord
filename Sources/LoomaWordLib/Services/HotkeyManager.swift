import Foundation
import AppKit
import Carbon.HIToolbox

/// Global hotkeys via Carbon `RegisterEventHotKey`.
///
/// Unlike `NSEvent.addGlobalMonitorForEvents`, Carbon hotkeys:
/// - do **not** require the Accessibility permission, and
/// - *consume* the keystroke, so ⌥Space / ⌘⇧D don't leak into other apps.
///
/// The double-⌘+C gesture is intentionally **not** handled here — it is detected by
/// `ClipboardMonitor` (pasteboard polling), which needs no permission at all.
@MainActor
public final class HotkeyManager {
    public static let shared = HotkeyManager()

    private static let signature: OSType = 0x4C4F4F4D // 'LOOM'
    private enum HotKey: UInt32 {
        case optionSpace = 1
        case commandShiftD = 2
    }

    public var onHotkeyPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private init() {}

    public func startMonitoring() {
        stopMonitoring()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = Unmanaged.passUnretained(self).toOpaque()
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr else { return status }

            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated {
                manager.handleHotKey(id: hotKeyID.id)
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            userData,
            &eventHandler
        )

        register(.optionSpace, keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey))
        register(.commandShiftD, keyCode: UInt32(kVK_ANSI_D), modifiers: UInt32(cmdKey | shiftKey))
    }

    private func register(_ id: HotKey, keyCode: UInt32, modifiers: UInt32) {
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id.rawValue)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            NSLog("HotkeyManager: RegisterEventHotKey failed for id %u (%d)", id.rawValue, status)
        }
    }

    public func stopMonitoring() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    private func handleHotKey(id: UInt32) {
        guard id == HotKey.optionSpace.rawValue || id == HotKey.commandShiftD.rawValue else { return }
        onHotkeyPressed?()
    }

    // Kept for compatibility — no longer required for any feature.
    public static func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    public static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
