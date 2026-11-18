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
        setupHotkeys()
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

    // MARK: - Hotkeys
    private func setupHotkeys() {
        HotkeyManager.shared.onHotkeyPressed = { [weak self] in
            Task { @MainActor in
                self?.toggleHUD()
            }
        }
        HotkeyManager.shared.startMonitoring()
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
