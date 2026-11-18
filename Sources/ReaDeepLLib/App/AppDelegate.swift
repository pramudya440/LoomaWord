import Cocoa
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public static let shared = AppDelegate()

    private var statusItem: NSStatusItem?
    private var hudWindow: NSPanel?
    private var mainWindow: NSWindow?
    private let coordinator = TranslationCoordinator.shared

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupHUDWindow()
        setupInterceptors()
    }

    // MARK: - Status Item
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "character.book.closed.fill", accessibilityDescription: "ReaDeepL")
            button.action = #selector(statusItemClicked)
            button.target = self
        }
    }

    @objc private func statusItemClicked() {
        toggleHUD()
    }

    // MARK: - Floating HUD Panel
    private func setupHUDWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 380),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true

        let hudView = FloatingHUDView(
            coordinator: coordinator,
            onExpandToFull: { [weak self] in
                self?.hudWindow?.orderOut(nil)
                self?.openMainWindow()
            },
            onClose: { [weak self] in
                self?.hudWindow?.orderOut(nil)
            }
        )

        panel.contentView = NSHostingView(rootView: hudView)
        panel.center()
        self.hudWindow = panel
    }

    public func toggleHUD() {
        guard let panel = hudWindow else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.center()
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            if coordinator.settings.autoTranslateClipboard {
                coordinator.pasteAndTranslate()
            }
        }
    }

    /// Triggers quick translation at the mouse cursor location (just like original DeepL Cmd+C+C)
    public func triggerQuickTranslate(withText text: String? = nil, atMouse: Bool = true) {
        guard let panel = hudWindow else { return }

        if let text = text, !text.isEmpty {
            coordinator.sourceText = text
            coordinator.triggerTranslation()
        } else {
            coordinator.pasteAndTranslate()
        }

        if atMouse {
            positionNearMouse(panel: panel)
        } else {
            panel.center()
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func positionNearMouse(panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame

        var originX = mouse.x - (panel.frame.width / 2)
        var originY = mouse.y - panel.frame.height - 20

        // Clamp horizontally
        originX = max(screenFrame.minX + 10, min(originX, screenFrame.maxX - panel.frame.width - 10))

        // If too low, place above cursor
        if originY < screenFrame.minY + 10 {
            originY = mouse.y + 20
        }
        // Clamp vertically
        originY = max(screenFrame.minY + 10, min(originY, screenFrame.maxY - panel.frame.height - 10))

        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    // MARK: - Main Workspace Window
    public func openMainWindow() {
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "ReaDeepL Pro Suite"
        window.contentView = NSHostingView(rootView: MainWindowView(coordinator: coordinator))
        window.isReleasedWhenClosed = false

        self.mainWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Interceptors (Hotkeys & Double ⌘+C)
    private func setupInterceptors() {
        // 1. Keyboard Hotkeys (⌥ Space, ⌘⇧D, and ⌘+C+C via key event)
        HotkeyManager.shared.onHotkeyPressed = { [weak self] in
            Task { @MainActor in
                self?.toggleHUD()
            }
        }

        HotkeyManager.shared.onDoubleCmdCPressed = { [weak self] in
            Task { @MainActor in
                self?.triggerQuickTranslate(atMouse: true)
            }
        }
        HotkeyManager.shared.startMonitoring()

        // 2. Clipboard Monitor for universal ⌘+C+C in any app without needing accessibility
        ClipboardMonitor.shared.onDoubleCopy = { [weak self] copiedText in
            Task { @MainActor in
                self?.triggerQuickTranslate(withText: copiedText, atMouse: true)
            }
        }
        ClipboardMonitor.shared.start()
    }
}

// MARK: - C Export for Launcher Stub
@_cdecl("reaDeepLMain")
public func reaDeepLMain() {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        let delegate = AppDelegate.shared
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
