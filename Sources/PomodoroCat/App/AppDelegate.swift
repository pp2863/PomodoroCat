import AppKit
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel!
    private var settingsWindowController: SettingsWindowController!
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
        let hosting = NSHostingView(rootView: CatView(engine: timerEngine))
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
        HistoryStore.shared.append(record)

        guard record.type == .focus else { return }
        let webhookString = SettingsStore.shared.webhookURLString
        guard !webhookString.isEmpty, let url = URL(string: webhookString) else { return }

        DiscordLogger.shared.postFocusComplete(
            minutes: record.durationMinutes,
            completedAt: record.completedAt,
            webhookURL: url
        ) { success in
            HistoryStore.shared.updateDiscordStatus(id: record.id, posted: success)
        }
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
