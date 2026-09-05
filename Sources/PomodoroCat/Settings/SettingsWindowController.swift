import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    init(settings: SettingsStore, timerEngine: TimerEngine) {
        let width = SettingsView.windowWidth
        let height: CGFloat = 560
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "PomodoroCat Settings"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: width, height: 320)
        window.maxSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        super.init(window: window)

        let hosting = NSHostingView(rootView: SettingsView(settings: settings, timerEngine: timerEngine))
        hosting.sizingOptions = []
        window.contentView = hosting
        window.setContentSize(NSSize(width: width, height: height))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
    }
}
