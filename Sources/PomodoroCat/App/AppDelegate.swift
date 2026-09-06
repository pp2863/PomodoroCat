import AppKit
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel!
    private var settingsWindowController: SettingsWindowController!
    private var statusItem: NSStatusItem!
    private var toggleVisibilityMenuItem: NSMenuItem!
    let timerEngine = TimerEngine(config: SettingsStore.shared.config)

    private let panelSize = NSSize(width: CatView.frameSize, height: CatView.frameSize)

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.shared.requestAuthorization()

        settingsWindowController = SettingsWindowController(settings: SettingsStore.shared, timerEngine: timerEngine)

        timerEngine.onSessionCompleted = { [weak self] record in
            self?.handleSessionCompleted(record)
        }

        let contentView = PanelContentView(frame: NSRect(origin: .zero, size: panelSize))
        let hosting = NSHostingView(
            rootView: CatView(
                engine: timerEngine,
                onBeginEditingTask: { [weak self] in self?.beginTaskEditing() },
                onEndEditingTask: { [weak self] in self?.endTaskEditing() }
            )
        )
        hosting.frame = contentView.bounds
        hosting.autoresizingMask = [.width, .height]
        contentView.addSubview(hosting)

        contentView.onToggle = { [weak self] in self?.timerEngine.togglePrimary() }
        contentView.onOpenSettings = { [weak self] in self?.settingsWindowController.show() }

        panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: panelSize), content: contentView)
        panel.setFrameOrigin(loadSavedOrigin() ?? defaultOrigin())
        panel.orderFrontRegardless()

        // Safety net: SwiftUI's empty Settings scene can briefly auto-open a blank
        // window at launch on some macOS versions. Make sure only our panel shows.
        for window in NSApp.windows where window !== panel {
            window.orderOut(nil)
        }

        setUpStatusItem()
    }

    // Tiny menu-bar affordance so the cat can be hidden (e.g. before a screen
    // share) and brought back — the floating panel itself offers no way to
    // do that once it's off-screen.
    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "🐱"

        let menu = NSMenu()
        toggleVisibilityMenuItem = NSMenuItem(
            title: "Hide Cat",
            action: #selector(toggleCatVisibility),
            keyEquivalent: "h"
        )
        toggleVisibilityMenuItem.target = self
        menu.addItem(toggleVisibilityMenuItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit PomodoroCat", action: #selector(quit), keyEquivalent: "q"))
        menu.items.last?.target = self
        statusItem.menu = menu
    }

    @objc private func toggleCatVisibility() {
        if panel.isVisible {
            panel.orderOut(nil)
            toggleVisibilityMenuItem.title = "Show Cat"
        } else {
            panel.orderFrontRegardless()
            toggleVisibilityMenuItem.title = "Hide Cat"
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    /// Typing needs key focus, which the panel refuses by default. Grant it (and
    /// activate, since a non-activating panel won't otherwise receive keys) only
    /// for as long as the user is actually editing.
    private func beginTaskEditing() {
        panel.allowsKeyFocus = true
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func endTaskEditing() {
        panel.allowsKeyFocus = false
        if NSApp.isActive {
            NSApp.deactivate()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let panel = panel {
            saveOrigin(panel.frame.origin)
        }
    }

    private func defaultOrigin() -> NSPoint {
        guard let screen = NSScreen.main else { return NSPoint(x: 100, y: 100) }
        let visible = screen.visibleFrame
        let margin: CGFloat = 24
        return NSPoint(x: visible.maxX - panelSize.width - margin, y: visible.minY + margin)
    }

    private func loadSavedOrigin() -> NSPoint? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "panelOriginX") != nil else { return nil }
        return NSPoint(x: defaults.double(forKey: "panelOriginX"), y: defaults.double(forKey: "panelOriginY"))
    }

    private func saveOrigin(_ point: NSPoint) {
        let defaults = UserDefaults.standard
        defaults.set(point.x, forKey: "panelOriginX")
        defaults.set(point.y, forKey: "panelOriginY")
    }

    private func handleSessionCompleted(_ record: SessionRecord) {
        NotificationManager.shared.notifySessionCompleted(type: record.type)

        // Only focus sessions are worth logging to the vault; breaks still go
        // into local history.
        var record = record
        if record.type == .focus {
            record.obsidianLogged = ObsidianLogger.shared.append(
                record,
                logPath: SettingsStore.shared.obsidianLogPath
            )
        }
        HistoryStore.shared.append(record)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
