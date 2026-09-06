import AppKit

/// Borderless, non-activating, always-on-top panel — clicking it never steals
/// focus or activation from whatever app the user is currently working in.
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect, content: NSView) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        self.contentView = content
    }

    /// Normally false so the panel never steals focus. Flipped on only while the
    /// user is deliberately typing the session's task, since keyboard input
    /// requires key status, then flipped straight back.
    var allowsKeyFocus = false

    override var canBecomeKey: Bool { allowsKeyFocus }
    override var canBecomeMain: Bool { false }
}

/// Handles all mouse interaction for the panel: double-click toggles the
/// timer, left-click-drag repositions the window, right-click (or clicking
/// the gear corner) opens Settings. Kept in AppKit rather than SwiftUI
/// gestures so drag and click-vs-drag disambiguation is fully reliable on a
/// borderless panel.
final class PanelContentView: NSView {
    var onToggle: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    private var mouseDownLocation: NSPoint = .zero
    private var didDrag = false

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = event.locationInWindow
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window else { return }
        let current = event.locationInWindow
        let dx = current.x - mouseDownLocation.x
        let dy = current.y - mouseDownLocation.y
        if abs(dx) > 3 || abs(dy) > 3 { didDrag = true }
        var frame = window.frame
        frame.origin.x += dx
        frame.origin.y += dy
        window.setFrame(frame, display: true)
        mouseDownLocation = current
    }

    override func mouseUp(with event: NSEvent) {
        guard !didDrag else { return }
        let point = convert(event.locationInWindow, from: nil)
        let gearFrame = CGRect(x: bounds.maxX - 48, y: bounds.maxY - 48, width: 48, height: 48)
        if gearFrame.contains(point) {
            onOpenSettings?()
        } else if event.clickCount == 2 {
            // Double-click (rather than single-click) to start/pause, so an
            // accidental stationary click while grabbing the cat to drag it
            // doesn't toggle the timer.
            onToggle?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onOpenSettings?()
    }
}
