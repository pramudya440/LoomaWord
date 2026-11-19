import Cocoa
import SwiftUI

// Custom NSPanel subclass that accepts keyboard input and handles Esc cleanly
final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        // Esc must also tear down the outside-click monitors, not just hide the panel.
        MainActor.assumeIsolated {
            AppDelegate.shared.dismissHUD()
        }
    }
}

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    public static let shared = AppDelegate()

    private var statusItem: NSStatusItem?
    private var hudWindow: HUDPanel?
    private var mainWindow: NSWindow?
    private var outsideClickGlobalMonitor: Any?
    private var outsideClickLocalMonitor: Any?
    private let coordinator = TranslationCoordinator.shared

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupStatusItem()
        setupHUDWindow()
        setupInterceptors()
    }

    /// Standard application menu. Without it the workspace has no Edit menu, so
    /// ⌘C / ⌘V / ⌘Z / ⌘Q don't work in the text views.
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Tentang LoomaWord", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Pengaturan...", action: #selector(menuOpenSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Sembunyikan LoomaWord", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Sembunyikan Lainnya", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Keluar dari LoomaWord", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        // Edit menu (required for copy/paste/undo in the text views)
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Potong", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Salin", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Tempel", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Pilih Semua", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        // Window menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Jendela")
        windowMenu.addItem(withTitle: "Buka Workspace", action: #selector(menuOpenWorkspace), keyEquivalent: "o").target = self
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Minimal", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenuItem.submenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    public func applicationWillTerminate(_ notification: Notification) {
        // Flush debounced settings/history writes so nothing is lost on quit.
        coordinator.flushPendingSaves()
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        // Double-clicking the app (or clicking the Dock) while it runs must give the
        // user a way back in — the app is an LSUIElement with no Dock icon otherwise.
        if hudWindow?.isVisible == true {
            dismissHUD()
        } else {
            openMainWindow()
        }
        return true
    }

    // MARK: - Status Item
    private func setupStatusItem() {
        if coordinator.settings.showMenuBarIcon {
            updateMenuBarIconVisibility(visible: true)
        }
    }

    public func updateMenuBarIconVisibility(visible: Bool) {
        if visible {
            // Clean up any existing item first so macOS attaches a fresh, active status item
            if let old = statusItem {
                NSStatusBar.system.removeStatusItem(old)
                statusItem = nil
            }
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.behavior = [.removalAllowed]
            if let button = item.button {
                button.image = NSImage(systemSymbolName: "character.bubble.fill", accessibilityDescription: "LoomaWord")
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
                button.action = #selector(statusItemClicked)
                button.target = self
            }
            item.isVisible = true
            self.statusItem = item
        } else {
            if let old = statusItem {
                NSStatusBar.system.removeStatusItem(old)
                statusItem = nil
            }
        }
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else {
            toggleHUD()
            return
        }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu()
        } else {
            toggleHUD()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let hudItem = NSMenuItem(title: "Buka LoomaWord HUD", action: #selector(menuOpenHUD), keyEquivalent: "")
        hudItem.target = self
        menu.addItem(hudItem)

        let workspaceItem = NSMenuItem(title: "Buka Workspace Penuh", action: #selector(menuOpenWorkspace), keyEquivalent: "o")
        workspaceItem.target = self
        menu.addItem(workspaceItem)

        let settingsItem = NSMenuItem(title: "Pengaturan...", action: #selector(menuOpenSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let hideItem = NSMenuItem(title: "Sembunyikan Icon dari Menu Bar", action: #selector(menuHideIcon), keyEquivalent: "")
        hideItem.target = self
        menu.addItem(hideItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Keluar dari LoomaWord", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }

    public func menuDidClose(_ menu: NSMenu) {
        statusItem?.menu = nil
    }

    @objc private func menuOpenHUD() {
        toggleHUD()
    }

    @objc private func menuOpenWorkspace() {
        openMainWindow()
    }

    @objc private func menuOpenSettings() {
        openMainWindow()
        UIState.shared.selectedTab = 3
    }

    @objc private func menuHideIcon() {
        coordinator.settings.showMenuBarIcon = false
        coordinator.saveSettings()
        updateMenuBarIconVisibility(visible: false)
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
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
        // 1. Keyboard hotkeys (⌥ Space, ⌘⇧D) via Carbon — no Accessibility permission.
        //    The double-⌘+C gesture is handled ONLY by ClipboardMonitor below, so it
        //    can never fire twice (previously both detectors triggered at once).
        HotkeyManager.shared.onHotkeyPressed = { [weak self] in
            Task { @MainActor [weak self] in
                self?.toggleHUD()
            }
        }
        HotkeyManager.shared.startMonitoring()

        // 2. Clipboard Monitor for universal ⌘+C+C in any app
        ClipboardMonitor.shared.onDoubleCopy = { [weak self] copiedText in
            Task { @MainActor [weak self] in
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
