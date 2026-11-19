import Cocoa
import SwiftUI

// Custom NSPanel subclass that accepts keyboard input and handles Esc cleanly
final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
}

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public static let shared = AppDelegate()

    private var statusItem: NSStatusItem?
    private var hudWindow: HUDPanel?
    private var mainWindow: NSWindow?
    private var outsideClickGlobalMonitor: Any?
    private var outsideClickLocalMonitor: Any?
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
            button.image = NSImage(systemSymbolName: "character.book.closed.fill", accessibilityDescription: "LoomaWord")
            button.action = #selector(statusItemClicked)
            button.target = self
        }
    }

    @objc private func statusItemClicked() {
        toggleHUD()
    }

    // MARK: - Floating HUD Panel
    private func setupHUDWindow() {
        let panel = HUDPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
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

        // Auto-dismiss when window loses key focus
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dismissHUD()
            }
        }

        let hudView = FloatingHUDView(
            coordinator: coordinator,
            onExpandToFull: { [weak self] in
                self?.dismissHUD()
                self?.openMainWindow()
            },
            onClose: { [weak self] in
                self?.dismissHUD()
            }
        )

        panel.contentView = NSHostingView(rootView: hudView)
        panel.center()
        self.hudWindow = panel
    }

    public func toggleHUD() {
        guard let panel = hudWindow else { return }
        if panel.isVisible {
            dismissHUD()
        } else {
            panel.center()
            showHUD(panel: panel)
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

        showHUD(panel: panel)
    }

    private func showHUD(panel: HUDPanel) {
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startOutsideClickMonitor()
    }

    public func dismissHUD() {
        stopOutsideClickMonitor()
        hudWindow?.orderOut(nil)
    }

    // MARK: - Auto-dismiss on Click Outside
    private func startOutsideClickMonitor() {
        stopOutsideClickMonitor()

        // Global monitor (clicks in other apps)
        outsideClickGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let panel = self?.hudWindow, panel.isVisible else { return }
                let mouse = NSEvent.mouseLocation
                if !panel.frame.contains(mouse) {
                    self?.dismissHUD()
                }
            }
        }

        // Local monitor (clicks within our own app windows/menus)
        outsideClickLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let panel = self?.hudWindow, panel.isVisible else { return event }
            let mouse = NSEvent.mouseLocation
            if !panel.frame.contains(mouse) {
                self?.dismissHUD()
            }
            return event
        }
    }

    private func stopOutsideClickMonitor() {
        if let g = outsideClickGlobalMonitor {
            NSEvent.removeMonitor(g)
            outsideClickGlobalMonitor = nil
        }
        if let l = outsideClickLocalMonitor {
            NSEvent.removeMonitor(l)
            outsideClickLocalMonitor = nil
        }
    }

    private func positionNearMouse(panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame

        var originX = mouse.x - (panel.frame.width / 2)
        var originY = mouse.y - panel.frame.height - 15

        // Clamp horizontally
        originX = max(screenFrame.minX + 10, min(originX, screenFrame.maxX - panel.frame.width - 10))

        // If too low, place above cursor
        if originY < screenFrame.minY + 10 {
            originY = mouse.y + 15
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
        window.title = "LoomaWord Pro Suite"
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

        // 2. Clipboard Monitor for universal ⌘+C+C in any app
        ClipboardMonitor.shared.onDoubleCopy = { [weak self] copiedText in
            Task { @MainActor in
                self?.triggerQuickTranslate(withText: copiedText, atMouse: true)
            }
        }
        ClipboardMonitor.shared.start()
    }
}

// MARK: - C Export for Launcher Stub
@_cdecl("loomaWordMain")
public func loomaWordMain() {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        let delegate = AppDelegate.shared
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
